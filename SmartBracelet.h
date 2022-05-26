#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H

// Message struct
typedef nx_struct sb_msg {
  	nx_uint8_t msg_type;
  	nx_uint8_t msg_id;

  	nx_uint8_t data[20];
  	nx_uint8_t X;
  	nx_uint8_t Y;
} sb_msg_t;

typedef struct sensorStatus {
  uint8_t status[20];
  uint8_t X;
  uint8_t Y;
}sensor_status;

// Constants
enum {
  AM_RADIO_TYPE = 6,
};

static const char *RANDOM_KEY[]={
	"ASDASDASDASDASDASDDD",
	"XCVXCVXCVXCVXCVXCVVV",
	"WEWERWERWRWERWERWEEE",
	"HJKHJKHJKHJKHJKHJKHJ",
};

#define PAIRING 0
#define CONFIRMATION 1
#define OPERATION 2
#define ALARM 3


#endif
