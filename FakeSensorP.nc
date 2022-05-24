#include <stdio.h>
generic module FakeSensorP() {

	provides interface Read<sensor_status>;
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
	  
	  sensor_status status;

	  int random_number = (call Random.rand16() % 10);
	  int random_x=(call Random.rand16()%10);
	  int random_y=(call Random.rand16()%10);
		
		if (random_number <= 2){
		  memcpy(status.status, "STANDING",20);
		} else if (random_number <= 5){
		  memcpy(status.status, "WALKING",20);
		} else if (random_number <= 8){
		  memcpy(status.status, "RUNNING",20);
		} else {
		  memcpy(status.status, "FALLING",20);
		}
	  
	  signal Read.readDone( SUCCESS, status);
	  status.X = random_x;
	  status.Y = random_y;
	dbg("Info","%d\n\n",random_x);
	}
}  
