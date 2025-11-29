#include <LiquidCrystal.h>  //library for LCD
#include <SoftwareSerial.h>

//defining Arduino Pins
#define Sensor A1
#define LEDR_R A2  //red for reading
#define LEDB_R A3  //blue for reading
#define LEDB 10
#define LEDG 9
#define LEDR 13
#define buzzer 8 // not working
#define select 6 // button 1
#define scroll 7 // button 2 
#define reading A5 // button 3 (NOT WORKING)
#define reset A0 // button 4

SoftwareSerial btSerial(1, 2);

int Upper_limit = 70;  //above this plant is healthy
int Lower_limit = 30;  // below this plant is un healthy

LiquidCrystal lcd(12, 11, 5, 4, 3, 2);  //lcd initalization
int value_RES = 0;                      //LDR sensor value

double avg_r = 0.0;  //average of 1 &2

typedef struct Reading{
  double blue;
  double red;
} readings;

void setup() {
  Serial.begin(9600);
  pinMode(Sensor, INPUT);
  pinMode(buzzer, OUTPUT);
  pinMode(LEDR_R, OUTPUT); // sensor led1 
  pinMode(LEDB_R, OUTPUT); // sensor led2
  pinMode(LEDB, OUTPUT);
  pinMode(LEDR, OUTPUT);
  pinMode(LEDG, OUTPUT);
  pinMode(select, INPUT_PULLUP); // ndefault value is HIGH, when pressed goes to LOW
  pinMode(scroll, INPUT_PULLUP);
  pinMode(reading, INPUT_PULLUP);
  pinMode(reset, INPUT_PULLUP);

  lcd.begin(16, 2);
  lcd.clear();

  btSerial.begin(9600);
  Serial.println("Bluetooth module started at 9600 baud.");

}

void loop() {
  if (btSerial.available()) {
    // Serial.write(btSerial.read());
    if (btSerial.read() == "ping"){
      btSerial.write("pong");
    }
  }

  // Forward data from Serial Monitor to Bluetooth module
  // if (Serial.available()) {
  //   btSerial.write(Serial.read());
  // }

  lcd.setCursor(0, 0);
  lcd.print("Smart");
  lcd.setCursor(0, 1);
  lcd.print("Jatamansi Sensor");

  waitForSelect();
  
  //reading1


  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Select to take");
  lcd.setCursor(0, 1);
  lcd.print("Reading 1");

  Serial.print("Reading 1: ");

  waitForSelect();

  readings r1 = get_reading();

  //reading 2

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Select to take");
  lcd.setCursor(0, 1);
  lcd.print("Reading 2");
  Serial.print("Reading 2 :");

  waitForSelect();
  readings r2 = get_reading();

  Serial.println(r1.blue);
  Serial.println(r1.red);
  Serial.println(r2.blue);
  Serial.println(r2.red);


  double avg_blue = (r1.blue + r2.blue)/2.d;
  double avg_red = (r1.red + r2.red)/2.d;


  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("RED LED: ");
  lcd.print(avg_red);
  lcd.setCursor(0, 1);
  lcd.print("NIR LED: ");
  lcd.print(avg_blue);
  
  waitForSelect();

  lcd.clear();
  lcd.setCursor(0, 0);

  if (avg_blue > 860){
    if (avg_red > 200 && avg_red < 600){
      lcd.print("Healthy");
      digitalWrite(LEDG, HIGH);
    }
    else{
      lcd.print("Sub-optimum");
      lcd.setCursor(0, 1);
      lcd.print("Detected");
      digitalWrite(LEDR, HIGH);
    }
  }  
  else{
    lcd.print("Sub-optimum");
    lcd.setCursor(0, 1);
    lcd.print("Detected");
    digitalWrite(LEDR, HIGH);
  }

  delay(250);
  waitForSelect();

  delay(250);
  lcd.clear();

  //Turning off all the LEDs

  digitalWrite(LEDG, LOW);
  digitalWrite(LEDB, LOW);
  digitalWrite(LEDR, LOW);
}


readings get_reading() {  //to get reading from sensor

  double value_LDR_B = 0.0;  //for blue LED
  double value_LDR_R = 0.0;  //for Red LED
  double alpha = 0.0;        //value of transitivity of red/blue

  delay(10);
  digitalWrite(LEDB_R, HIGH);
  delay(90);
  long long int timer = millis();
  while (abs(millis() - timer) < 600) {
    Serial.print("Reading :");
    value_LDR_B = analogRead(Sensor);
    Serial.println(value_LDR_B);
  }
  digitalWrite(LEDB_R, LOW);
  delay(150);
  digitalWrite(LEDR_R, HIGH);
  delay(90);
  timer = millis();
  while (abs(millis() - timer) < 600) {
    Serial.print("Reading :");
    value_LDR_R = analogRead(Sensor);
    Serial.println(value_LDR_R);
  }
  digitalWrite(LEDR_R, LOW);

  readings r;
  r.red = value_LDR_R;
  r.blue = value_LDR_B;

  delay(100);

  return r;
  
}

void waitForSelect(){
  while (1){
    if (!digitalRead(select)){
      break;
    }
  }
  beep();
  delay(150);
}

void beep() {  //beep sound
  digitalWrite(buzzer, HIGH);
  delay(50);
  digitalWrite(buzzer, LOW);
  return;
}