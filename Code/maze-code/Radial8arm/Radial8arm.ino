/*
 * Radial 8-arm maze
 * 
 * The mouse is foraging in an 8-arm maze for water rewards. Three solenoids are attached to the end of one arm each (reward arms) while the other
 * arms are never baited. These are defined in the first variable. On each new trial, all reward arms become 'enabled', i.e. the solenoid will
 * dispense water when the mouse enters the arm. Once the mouse has entered all rewarded arms, the trial number is incremented by one and the setup
 * is reset to its intial condition.
 * 
 */

#include <MsTimer2.h>

// Rewarded arms (1-INDEX!); Max number is determined by the number of solenoids!
int rewarded[3] = {2,3,6};

// pin numbers for IR sensors and solenoids; Specify numbers here for for-loops later
const int nIRs = 8;
const int pinsIR[nIRs] = {22,23,24,25,26,27,28,29};
const int nValves = 3;
const int pinsValve[nValves] = {30,31,32};

// Output pins to intan
const int pinSync = 53; // For Intan/Camera sync
const int pinIntanTrial = 50; // Signal trial completion

// Variables
int valveDelay = 30; //Solenoid open time in ms
int trialCount = 0;
int intertrialinterval = 2000; // Pause between trials in ms
bool syncState = false; // Sync state
bool entered[3] = {false, false, false}; // Automatically initialized with zeros
bool visited[3] = {false, false, false}; // 'visited' implies the animal has entered AND subsequently left the arm
long entrytime[3] = {0,0,0};


void setup() {
  // convert rewarded to 0-based index
  rewarded[0]=rewarded[0]-1;
  rewarded[1]=rewarded[1]-1;
  rewarded[2]=rewarded[2]-1;
  
  pinMode(A0,INPUT); //DEBUG
  pinMode(pinSync, OUTPUT);
  pinMode(pinIntanTrial, OUTPUT);
  
  for (int v=0; v<nValves; v+=1) {
    pinMode(pinsValve[v], OUTPUT);
    digitalWrite(pinsValve[v], LOW);
  }

  for (int i=0; i<nIRs; i+=1) {
    pinMode(pinsIR[i], INPUT);
  }
 
  // set ouptut pins to LOW
  digitalWrite(pinIntanTrial, LOW);
  
  // MsTimer setup, running every 1000 ms
  MsTimer2::set(1000,flash); // run flash every 1000 ms
  MsTimer2::start(); //enable the interrupt

  Serial.begin(9600);
}

void loop() {

  /*
   * Monitor whether any of the rewarded arm barriers has been crossed
   */

  for (int a=0; a<3; a+=1) {
    if (digitalRead(pinsIR[rewarded[a]])==LOW) {
      if (!entered[a] && !visited[a]) {
        entered[a] = true;
        // Open solenoid to dispense reward
        digitalWrite(pinsValve[a], HIGH);
        delay(valveDelay); 
        digitalWrite(pinsValve[a], LOW);
        entrytime[a] = millis();
        Serial.print(rewarded[a]+1); Serial.println(" arm entered");
      }

      // Set arm as visited during exit. 1 second debounce delay for sensor
      if (entered[a] && (millis()-entrytime[a]>1000) && !visited[a]) {
        visited[a] = true;
        entered[a] = false;
        Serial.print(rewarded[a]+1); Serial.println(" arm left");
      }
    }
    
    // Reset arm if not exited within 10 seconds after entry   
    if (entered[a] && (millis()-entrytime[a]>20000) && !visited[a]) {
      visited[a] = true;
      entered[a] = false;
      Serial.print(rewarded[a]+1); Serial.println(" arm timeout");
    }
  }

  // Start new trial once all arms have been entered
  if (visited[0] && visited[1] && visited[2]) {
    // 5 second delay between trials to avoid immediate re-entry to the last arm
    delay(intertrialinterval);
    visited[0] = false;
    visited[1] = false;
    visited[2] = false;

    digitalWrite(pinIntanTrial, HIGH);
    delay(5);
    digitalWrite(pinIntanTrial, LOW);
    
    trialCount+=1;
    Serial.print("Trial #:");
    Serial.println(trialCount);
  }
}

void flash(){
  syncState = !syncState;
  digitalWrite(pinSync, syncState);
}
