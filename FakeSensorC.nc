generic configuration FakeSensorC() 
{
	provides interface Read<sensor_msg_t>;
} 

implementation 
{

	components MainC, RandomC;
	components new FakeSensorP();
	
	//Connects the provided interface
	Read = FakeSensorP;
	
	//Random interface and its initialization	
	FakeSensorP.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;

}
