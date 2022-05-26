#include "Timer.h"
#include "SmartBracelet.h"
#include <stdio.h>

module SmartBraceletC @safe() {
  uses {
    interface Boot;
    
    interface AMSend;
    interface Receive;
    interface SplitControl as AMControl;
    interface Packet;
    interface AMPacket;
    interface PacketAcknowledgements;
    
    interface Timer<TMilli> as TimerPairing;
    interface Timer<TMilli> as Timer10s;
    interface Timer<TMilli> as Timer60s;
    
    interface Read<sensor_status> as FakeSensor;
  
  }
}

implementation {
  
  // Radio control
  bool busy = FALSE;
  uint16_t counter = 0;
  message_t packet;
  am_addr_t address_coupled_device;
  uint8_t attempt = 0;
  
  // Current and previous phase
  uint8_t phase = 0;
  uint8_t prev_phase = 0;
  
  // Sensors
  //bool sensors_read_completed = FALSE;
  
  sensor_status status;
  sensor_status last_status;
  
  void send_confirmation();
  void send_info_message();
  
  // Program start
  event void Boot.booted() {
    call AMControl.start();
  }

  // called when radio is ready
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      dbg("Radio", "Radio device ready\n");
      dbg("Pairing", "PAIRING Phase started\n");
      
      // Start pairing phase
      call TimerPairing.startPeriodic(250);
    } else {
      call AMControl.start();
    }
  }
  
  event void AMControl.stopDone(error_t err) {}
  
 
  event void TimerPairing.fired() {
    counter++;
    dbg("TimerPairing", "TimerPairing is fired @ %s\n", sim_time_string());
    if (!busy) {
      sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
      
      // Fill payload
      sb_pairing_message->msg_type = PAIRING; // 0 for pairing phase
      sb_pairing_message->msg_id = counter;
      //The node ID is divided by 2 so every 2 nodes will be the same number (0/2=0 and 1/2=0)
      //we get the same key for every 2 nodes: parent and child
      memcpy(sb_pairing_message->data, RANDOM_KEY[TOS_NODE_ID/2],20);
      call PacketAcknowledgements.requestAck( &packet );
      
      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(sb_msg_t)) == SUCCESS) {
	      dbg("Radio", "Broadcasting pairing packet with key=%s\n", RANDOM_KEY[TOS_NODE_ID/2]);	
	      busy = TRUE;
      }
    }
  }
  
  // Timer10s fired
  event void Timer10s.fired() {
    dbg("Timer10s", "Timer10s is fired @ %s\n", sim_time_string());
    call FakeSensor.read();
  }

  // Timer60s fired
  event void Timer60s.fired() {
    dbg("Timer60s", "Timer60s is fired @ %s\n", sim_time_string());
    dbg("Info", "ALERT: MISSING\n");
    dbg("Info","Last known location: %hhu, Y: %hhu\n", last_status.X, last_status.Y);

    //send to serial here

  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr && error == SUCCESS) {
      dbg("Radio_sent", "Packet sent\n");
      busy = FALSE;
      
      if(phase == PAIRING){
		dbg("Pairing","Pairing message broadcasting completed!\n\n");            
      }else if (phase == CONFIRMATION && prev_phase == PAIRING){
       dbg("Pairing","Pairing message broadcasting completed!\n\n");
       }
       
      if(phase == CONFIRMATION && call PacketAcknowledgements.wasAcked(bufPtr) ){
        // PHASE == 1 and ack received
        phase = OPERATION; // Pairing phase 1 completed
        dbg("Radio_ack", "PAIRING-ACK received at time %s\n", sim_time_string());
        dbg("Pairing","PAIRING completed for mote: %hhu\n\n", address_coupled_device);
        
        // Start operational phase
        if (TOS_NODE_ID % 2 == 0){
          // Parent bracelet
          dbg("OperationalMode","Parent bracelet\n\n");
          //call SerialControl.start();
          call Timer60s.startOneShot(60000);
        } else {
          // Child bracelet
          dbg("OperationalMode","Child bracelet\n\n");
          call Timer10s.startPeriodic(10000);
        }
      
      }else if (phase == CONFIRMATION && prev_phase == PAIRING){
      	prev_phase=CONFIRMATION;	
		send_confirmation(); 
      }else if (phase == CONFIRMATION){
        // PHASE == 1 but ack not received
        dbg("Radio_ack", "CONF-ACK not received in CONFIRMATION phase\n\n");
        send_confirmation(); // Send confirmation again
      
      } else if (phase == OPERATION && call PacketAcknowledgements.wasAcked(bufPtr)){
        // PHASE == 2 and ack received
        dbg("Radio_ack", "INFO-ACK received at time %s\n\n", sim_time_string());
        attempt = 0;
        
      } else if (phase == OPERATION){
        // PHASE == 2 and ack not received
        dbg("Radio_ack", "INFO-ACK not received in OPERATION phase\n\n");
        send_info_message();
      }
        
    }
  }
  
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    sb_msg_t* mess = (sb_msg_t*)payload;
    // Print data of the received packet
	  dbg("Radio_rec","Message received from mote %hhu at time %s\n", call AMPacket.source( bufPtr ), sim_time_string());
	  dbg("Info","|-------------------------------------------------------------|\n");
	  dbg("Radio_pack","|\tPayload: type: %hu, msg_id: %hhu, data: %-22s|\n", mess->msg_type, mess->msg_id, mess->data);
    
    if (call AMPacket.destination( bufPtr ) == AM_BROADCAST_ADDR && phase == PAIRING && memcmp(mess->data, RANDOM_KEY[TOS_NODE_ID/2],20) == 0){
      address_coupled_device = call AMPacket.source( bufPtr );
      phase = CONFIRMATION; //  confirmation of pairing 
      dbg("Radio_pack","|\tMessage for PAIRING request received. Address: %-10hhu|\n", address_coupled_device);
      dbg("Info","|-------------------------------------------------------------|\n");
      send_confirmation();
    
    } else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == CONFIRMATION) {
      // Enters if the packet is for this destination and if the msg_type == 1
      dbg("Radio_pack","|\t%-57s|\n","Message for CONFIRMATION received");
      dbg("Info","|-------------------------------------------------------------|\n");
      call TimerPairing.stop();
      
    } else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == OPERATION) {
      // Enters if the packet is for this destination and if msg_type == 2
      //dbg("Info","|-------------------------------------------------------------|\n");
      dbg("Radio_pack","|\t%-57s|\n","INFO message received");
      dbg("Info", "|\tPosition X: %hu, Y: %-38hu |\n", mess->X, mess->Y);
      dbg("Info", "|\tSensor status: %-41s |\n", mess->data);
      last_status.X = mess->X;
      last_status.Y = mess->Y;
      call Timer60s.startOneShot(60000);
      
      // check if FALLING
      if (memcmp(mess->data, "FALLING",20) == 0){
        dbg("Info", "ALERT: FALLING!\n");
 	//send to serial here
 	    
      }
      dbg("Info","|-------------------------------------------------------------|\n");
    }

    

    return bufPtr;
  }

  event void FakeSensor.readDone(error_t result, sensor_status status_local) {
    status = status_local;
    dbg("Info","|-------------------------------------------------------------|\n");
    dbg("Sensors", "|\tSensor status: %-42s|\n", status.status);
    dbg("Sensors", "|\tPosition X: %hhu, Y: %-39hhu|\n", status_local.X, status_local.Y);
    dbg("Info","|-------------------------------------------------------------|\n");

    send_info_message();
    

  }

  // Send confirmation in phase 1
  void send_confirmation(){
    counter++;
    if (!busy) {
      sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
      
      // Fill payload
      sb_pairing_message->msg_type = CONFIRMATION; // confirmation of pairing
      sb_pairing_message->msg_id = counter;
      
      memcpy(sb_pairing_message->data, RANDOM_KEY[TOS_NODE_ID/2],20);
      
      // Require ack
      call PacketAcknowledgements.requestAck( &packet );
      
      if (call AMSend.send(address_coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
        dbg("Radio", "Sending CONFIRMATION to mote %hhu\n", address_coupled_device);	
        busy = TRUE;
      }
    }
  }
  
  // Send INFO message from child's bracelet
  void send_info_message(){
    
    if (attempt < 3){
      counter++;
      if (!busy) {
        sb_msg_t* sb_pairing_message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
        
        // Fill payload
        sb_pairing_message->msg_type = OPERATION; // 2 for INFO packet
        sb_pairing_message->msg_id = counter;
        
        sb_pairing_message->X = status.X;
        sb_pairing_message->Y = status.Y;
        memcpy(sb_pairing_message->data, status.status,20);
        
        // Require ack
        attempt++;
        call PacketAcknowledgements.requestAck( &packet );
        
        if (call AMSend.send(address_coupled_device, &packet, sizeof(sb_msg_t)) == SUCCESS) {
          dbg("Radio", "Radio: sending INFO packet to mote %hhu, attempt: %d\n", address_coupled_device, attempt);	
          busy = TRUE;
        }
      }
    } else {
      attempt = 0;
    }
  }
  
}




