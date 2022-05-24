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
/*
// Pre-loaded random keys
#define FOREACH_KEY(KEY) \
        KEY(BFBD2d3VsBNIsfJO68dI) \
        KEY(xr3gBthvdhvFhvB6iHUH) \
        KEY(ygxbbBb7UUYUYGiubiuh) \
        KEY(sacuycagb7Nun0u90m9I) \
        KEY(IMIMi09i9ioinhbvdc5c) \
        KEY(q65v76tb8n98u09mu9n8) \
        KEY(nuyb8byn98uiyi8u9uBF) \
        KEY(BD2d3VsBNIsfJO68dIby) \
        
#define GENERATE_ENUM(ENUM) ENUM,
#define GENERATE_STRING(STRING) #STRING,
enum KEY_ENUM {
    FOREACH_KEY(GENERATE_ENUM)
};
static const char *RANDOM_KEY[] = {
    FOREACH_KEY(GENERATE_STRING)
};
*/
#endif
