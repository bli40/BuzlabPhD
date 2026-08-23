#include <Servo.h>

Servo myservo;  // create servo object to control a servo
// twelve servo objects can be created on most boards

int pos = 0;    // variable to store the servo position

const int pinsIR = 22;
const int pinsPumps = 50;
const int pinBuzzer = 13;

int home = 1;

int lastIR = 0;
int trialNum = 1;
int completedTrials = 0;
int pumpDur = 20;
int ITI = 2000;

unsigned long previousMillis = 0;  // will store last time LED was updated
long pumpStartTime = 0;
long trialStartTime = 0;
long delayStartTime = 0;


void setup() {
  myservo.attach(2, 500, 2500);  // attaches the servo on pin 9 to the servo object

  pinMode(pinsIR, INPUT);
  pinMode(pinsPumps, OUTPUT);
  digitalWrite(pinsPumps,LOW);

  pinMode(51, OUTPUT);
  pinMode(52, OUTPUT);
  pinMode(53, OUTPUT);
  digitalWrite(51, LOW);
  digitalWrite(52, LOW);
  digitalWrite(53, LOW);


  pinMode(pinBuzzer, OUTPUT);

  home -= 1;

  Serial.begin(115200);
  delay(1000);
  Serial.println("***** System Ready - Nosepoke Operant Box *****");
  Serial.print("ITI: "); Serial.println(ITI/1000.0);
  Serial.print("Home: "); Serial.println(home);
  Serial.print("### Trial "); Serial.println(trialNum);

  myservo.write(120);
  
  trialStartTime = millis();
}

// the loop function runs over and over again forever
void loop() {
  // Checks every nosepoke port and displays if entered (rising edge). If cued, then start reward dispensing.
  if (digitalRead(pinsIR) == HIGH & lastIR == 0) {
    lastIR = 1;

    Serial.print(0);
    Serial.print(" poked @ ");
    Serial.print((millis() - trialStartTime)/1000.0);
    Serial.println("s");
    
    digitalWrite(pinsPumps, HIGH);
    delay(pumpDur);
    digitalWrite(pinsPumps, LOW);
    
    Serial.print("<<<");
    Serial.print(0);
    Serial.println(" rewarded>>>");

    Serial.print("Completed Trial ");
    Serial.println(trialNum);
    delay(ITI);
    tone(pinBuzzer,3000,500);
    trialNum += 1;
    Serial.print("### Trial "); Serial.println(trialNum);
    trialStartTime = millis();
  }
  // Resets poked state once exited (falling edge).
  if (digitalRead(pinsIR) == LOW & lastIR == 1) {
    lastIR = 0;
  }
  
}
