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
  uint8_t phase[] = {0,0,0,0};

  
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
    dbg("Info","Last known location: %hhu, Y: %hhu\n\n", last_status.X, last_status.Y);

    //send to serial here

  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr && error == SUCCESS) {
      sb_msg_t* message = (sb_msg_t*)call Packet.getPayload(&packet, sizeof(sb_msg_t));
      dbg("Radio_sent", "Packet sent\n");
      busy = FALSE;
      
      if (message->msg_type == PAIRING){
       dbg("Pairing","Pairing message broadcasting completed!\n\n");
      
       }else if(phase[TOS_NODE_ID] == CONFIRMATION && call PacketAcknowledgements.wasAcked(bufPtr) ){
        // PHASE == 1 and ack received
        
        phase[TOS_NODE_ID] = OPERATION; // Pairing phase 1 completed
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
      
      }else if (phase[TOS_NODE_ID] == CONFIRMATION){
        // PHASE == 1 but ack not received
        dbg("Radio_ack", "CONF-ACK not received in CONFIRMATION phase\n\n");
        send_confirmation(); // Send confirmation again
      
      } else if (phase[TOS_NODE_ID] == OPERATION && call PacketAcknowledgements.wasAcked(bufPtr)){
        // PHASE == 2 and ack received
        dbg("Radio_ack", "INFO-ACK received at time %s\n\n", sim_time_string());
        attempt = 0;
        
      } else if (phase[TOS_NODE_ID] == OPERATION){
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
	  dbg_clear("Info","\t|-----------------------------------------------------------------|\n");
	  dbg_clear("Radio_pack","\t|\tPayload: type: %hu, msg_id: %hhu, data: %-23s|\n", mess->msg_type, mess->msg_id, mess->data);
    
    if (call AMPacket.destination( bufPtr ) == AM_BROADCAST_ADDR && memcmp(mess->data, RANDOM_KEY[TOS_NODE_ID/2],20) == 0){
      address_coupled_device = call AMPacket.source( bufPtr );
      phase[TOS_NODE_ID] = CONFIRMATION; //  confirmation of pairing 
      dbg_clear("Radio_pack","\t|\tMessage for PAIRING request received. Mote: %-14hhu|\n", address_coupled_device);
      dbg_clear("Info","\t|\t%-50s|\n","This is the pair device!");
      dbg_clear("Info","\t|-----------------------------------------------------------------|\n");
      send_confirmation();
    
    } else if(call AMPacket.destination( bufPtr ) == AM_BROADCAST_ADDR ){
      dbg_clear("Radio_pack","\t|\tMessage for PAIRING request received. Mote: %-14hhu|\n", call AMPacket.source( bufPtr ));
      dbg_clear("Radio_pack","\t|\tThis is not the right pair. Mote:%-20hhu|\n", call AMPacket.source( bufPtr ));
      dbg_clear("Info","\t|-----------------------------------------------------------------|\n");
    
    }else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == CONFIRMATION) {
      // Enters if the packet is for this destination and if the msg_type == 1
      dbg_clear("Radio_pack","\t|\t%-58s|\n","Message for CONFIRMATION received");
      dbg_clear("Info","\t|-----------------------------------------------------------------|\n");
      call TimerPairing.stop();
      
    } else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == OPERATION) {
      // Enters if the packet is for this destination and if msg_type == 2
      //dbg("Info","|-------------------------------------------------------------|\n");
      dbg_clear("Radio_pack","\t|\t%-58s|\n","INFO message received");
      dbg_clear("Info", "\t|\tPosition X: %hu, Y: %-39hu |\n", mess->X, mess->Y);
      dbg_clear("Info", "\t|\tSensor status: %-42s |\n", mess->data);
      dbg_clear("Info","\t|-----------------------------------------------------------------|\n");
      last_status.X = mess->X;
      last_status.Y = mess->Y;
      // check if FALLING
      if (memcmp(mess->data,"FALLING",20) == 0){
      
        dbg("Info", "ALERT: FALLING!\n");
 		//send to serial here
      }
      call Timer60s.startOneShot(60000);
    }
    return bufPtr;
  }

  event void FakeSensor.readDone(error_t result, sensor_status status_local) {
    status = status_local;
    dbg_clear("Info","\t|-----------------------------------------------------------------|\n");
    dbg_clear("Sensors", "\t|\tSensor status: %-42s|\n", status.status);
    dbg_clear("Sensors", "\t|\tPosition X: %hhu, Y: %-39hhu|\n", status_local.X, status_local.Y);
    dbg_clear("Info","\t|-----------------------------------------------------------------|\n");

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




