#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H

// Message struct
typedef nx_struct msg {
  	nx_uint8_t msg_type;
  	nx_uint8_t data[20];
  	nx_uint8_t X;
  	nx_uint8_t Y;
} msg_t;

//sensor message
typedef struct sensor_msg {
  uint8_t status[20];
  uint8_t X;
  uint8_t Y;
}sensor_msg_t;

// Constants
enum {
  AM_RADIO_TYPE = 6,
};
uint8_t falling_msg[20]="FALLING";

//Random key list
static const char *RANDOM_KEY[]={
	"mcyurZJMIZROKf3zIHAi",
	"TQ7cy9OZrGimlEOhaUPE",
	"NNRVLfiNOfpmuvbj8o0Y",
	"AZT25vwFz5yJKBnywvci",
};

//phases
#define PAIRING 0
#define CONFIRMATION 1
#define OPERATION 2



#endif
