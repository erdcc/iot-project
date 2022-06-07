#include <stdio.h>
generic module FakeSensorP() {

	provides interface Read<sensor_msg_t>;
	uses interface Random;

}

implementation 
{

	task void readDone();

	//***************** Read interface ********************//
	command error_t Read.read(){
		post readDone();
		return SUCCESS;
	}

	//******************** Read Done **********************//
	task void readDone() {
	  
	  sensor_msg_t mess;

	  int random_number = (call Random.rand16() % 10);
	  int random_x=(call Random.rand16()%10);
	  int random_y=(call Random.rand16()%10);
		
		if (random_number <= 2){
		  memcpy(mess.status, "STANDING",20);
		} else if (random_number <= 5){
		  memcpy(mess.status, "WALKING",20);
		} else if (random_number <= 8){
		  memcpy(mess.status, "RUNNING",20);
		} else {
		  memcpy(mess.status, "FALLING",20);
		}
	
	  mess.X = random_x;
	  mess.Y = random_y;
	  
	  signal Read.readDone( SUCCESS, mess);
	  
	}
}  
