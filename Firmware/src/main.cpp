#include <Arduino.h>
#include <IOCPMessenger.h>

#define DEBUG

typedef struct updatedata_t {
  long position;
  long value;
} UpdateEntry;
UpdateEntry *updateEntries;

IOCPMessenger iocpMessenger = IOCPMessenger(Serial);

// Function Prototypes
void updateConnectedDevices();

void OnKeepAlive()
{
  iocpMessenger.sendCmdStart("Vivo");
  iocpMessenger.sendCmdEnd();
}

void OnUpdate() {

  while (char *data = iocpMessenger.readStringArg()) {

    char *p = NULL;
    
    // Functions manipulates data var. To preserve it might be necessary to create a copy of data
    // to leave the data var untouched
    char *copy = (char *)malloc(sizeof(data));
    strcpy(copy, data);

    char *positionStr = strtok_r(copy, "=", &p);
    char *valueStr = strtok_r(NULL, "=", &p);

    if (positionStr == NULL || valueStr == NULL) {
      free(copy);
      continue;
    }

    long position = atol(positionStr);
    long value = atol(valueStr);
    free(copy);

    // Store update values in global list for postprocessing (later in runloop)
    int size = (updateEntries == NULL) ? sizeof(UpdateEntry) : sizeof(*updateEntries) + sizeof(UpdateEntry);
    int index = (size / sizeof(UpdateEntry)) - 1;

    UpdateEntry newEntry = { position, value };
    UpdateEntry *bufferMemory = (UpdateEntry *)realloc(updateEntries, size);
    if (bufferMemory == NULL) {
      // Unable to allocate new memory
      free(updateEntries);
      exit(EXIT_FAILURE);
    } else {
      updateEntries = bufferMemory;
    }

    updateEntries[index] = newEntry;

    #ifdef DEBUG
    char result[60];
    snprintf(result, sizeof(result), "Update %ld with %ld",position, value);
    iocpMessenger.sendCmd("Stat", result);
    #endif 
  }

}

void OnUnknownCommand() {
    Serial.print("Unknown IOCP-Command: ");
    Serial.println(iocpMessenger.getLastCommand());
}

void attachCommandCallbacks() {
  
  // Attach callback methods
  iocpMessenger.attach(OnUnknownCommand);
  iocpMessenger.attach("Vivo", OnKeepAlive);
  iocpMessenger.attach("Resp", OnUpdate);

#ifdef DEBUG
  iocpMessenger.sendCmd("Stat", F("Attached callbacks"));
#endif
}

void setup() {

  Serial.begin(9600);

  attachCommandCallbacks();
}

void loop() {

  iocpMessenger.feedinSerialData();
  updateConnectedDevices();
}

void updateConnectedDevices() {

  if (updateEntries == NULL) {
    return;
  }

  int size = sizeof(*updateEntries) / sizeof(UpdateEntry);
  for (int index = 0; index < size; index++) {
    
    UpdateEntry entry = updateEntries[index];
    Serial.print("Updating ");
    Serial.print(entry.position);
    Serial.print(" --> ");
    Serial.println(entry.value);
  }

  free(updateEntries);
  updateEntries = NULL;
}