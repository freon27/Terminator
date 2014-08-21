import ddf.minim.spi.*;
import ddf.minim.signals.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;
import ddf.minim.effects.*;

import gab.opencv.*;
import processing.video.*;
import java.awt.*;

Capture video;
OpenCV opencv;

Minim minim;
AudioInput in;
FFT fft;
 
PFont font; 

float loudestFreqAmp = 0;
float loudestFreq = 0;
int timerCounter = 0;

String insults[];

int w=640/2;
int h=480/2;
PImage tvscreen;
PImage TVOverlay;
PImage tvnoise;
PImage targetImage;
PImage gun;
PImage targetReticule;
PImage targetReticuleBright;
PGraphics pg;
boolean currentTargetPositive = false;

int target = -1;

int barY1=10;
int barY2=30;
int[] facesProgress;

String[] symbols = new String[6];


//tv noise
int[] ppx;
int[] px = new int[w];

boolean tvstate = true;


long timeIndexInfo;
long firstCountInfo;

float lerpAmount = 0;
float lerpScale = 0;
float lerpShrink = 0;

int tvheight=0;
int tvwidth=0;

int faceCount = 0;
int scl = 1;

class Face {
  
  // A Rectangle
  Rectangle r;
  
  // Am I available to be matched?
  boolean available;
  
  // Should I be deleted?
  boolean delete;
  
  int insult1 = int(random(0, insults.length));
  
  int insult2 = int(random(0, insults.length));
  
  
 
  int threatLevel = int(random(0, 25));
 
  // How long should I live if I have disappeared?
  int timer = 25;
  
  // Assign a number to each face
  int id;
  
  // Make me
  Face(int x, int y, int w, int h) {
    r = new Rectangle(x,y,w,h);
    available = false;
    delete = false;
    id = faceCount;
    faceCount++;
    facesProgress[id] = 0;
    while(insult1 == insult2){
      insult2 = int(random(0, insults.length));
    }
  }

  // Show me
  void display() {
    /*
    fill(0,0,255,timer);
    stroke(0,0,255);
    rect(r.x*scl,r.y*scl,r.width*scl, r.height*scl);
    fill(255,timer*2);
    text(""+id,r.x*scl+10,r.y*scl+30);
    */
    pg.noFill();
      pg.stroke(255,255,255,timer * 2);
      pg.strokeWeight(2);
      // right line
      pg.line(r.x + r.width , r.y, r.x + r.width, r.y + r.height);
      // top line
      pg.line(r.x, r.y, r.x + r.width, r.y);
      pg.stroke(255,255,255, timer * 2);
      pg.fill(255, 255, 255, 80);
      pg.textSize(8);
      pg.text("Unknown agent: " + id, r.x + r.width + 20, r.y + 10);
      
      
      if (available){
          pg.text("Tracking lost", r.x + r.width + 20, r.y + 30);
      }
      else if(facesProgress[id] >= 30){
        pg.text(insults[insult1], r.x + r.width + 20, r.y + 30);
        pg.text(insults[insult2], r.x + r.width + 20, r.y + 50);
        pg.text("Threat level: " + threatLevel + "%", r.x + r.width + 20, r.y + 70);
      }
     else {
       pg.text("Assessing threat level", r.x + r.width + 20, r.y + 30);
       pg.text(symbols[facesProgress[id] % 4], r.x + r.width + 20, r.y + 50);
     } 
    
  }

  // Give me a new location / size
  // Oooh, it would be nice to lerp here!
  void update(Rectangle newR) {
    r = (Rectangle) newR.clone();
  }

  // Count me down, I am gone
  void countDown() {
    timer--;
  }

  // I am deed, delete me
  boolean dead() {
    if (timer < 0) return true;
    return false;
  }
}
ArrayList faceList;

void setup() {
  
  font = createFont("New", 8, true);
  textFont(font);
  
  
  size(displayWidth, displayHeight);
  video = new Capture(this, 640/2, 480/2);
  opencv = new OpenCV(this, 640/2, 480/2);
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);  
  pg = createGraphics(640, 480);
  
  video.start();

  faceList = new ArrayList<Face>();
  
  insults = loadStrings("insults.txt");
 
  gun = loadImage("handgun.png");
  
  symbols[0] = "|";
  symbols[1] = "/";
  symbols[2] = "-";
  symbols[3] = "\\";

  minim = new Minim(this);
  minim.debugOn();
  background(255);
  noStroke();
  // get a line in from Minim, default bit depth is 16
  in = minim.getLineIn(Minim.STEREO, 1024);
  fft = new FFT(in.bufferSize(), in.sampleRate());

  facesProgress = new int[1000];
  
    //tvscreen=loadImage("obey2.png");
  TVOverlay=loadImage("tv.png");

  targetReticule = loadImage("target.png");
  targetReticuleBright = loadImage("targ_bright.png");
   
  // precalculate tv noise
  tvnoise = createImage(w,h,RGB);

  tvnoise.loadPixels();
  ppx = new int[tvnoise.pixels.length];
  for (int y = 0; y < ppx.length;)
    ppx[y++] = int(random(-32,32));
  loadPixels();


  tvwidth = w;
  tvheight = h;

  timeIndexInfo = millis();
  firstCountInfo = millis();

  noSmooth();

}

void draw() {
  pg.beginDraw();
  pg.background(0);
  pg.scale(2);
  opencv.loadImage(video);

  
  tvscreen = video.get();
    
  //renderDistort();
  tvscreen.filter(POSTERIZE, 8);
  pg.image(tvscreen, 0, 0);
  pg.tint(255,150,150, 100);
  
  pg.fill(100,100,100,60);
  pg.noStroke();
  pg.strokeWeight(0);
  Rectangle[] faces = opencv.detect();
  println(faces.length);
  //pg.image(gun, 640 - (gun.width / 4) , 480 - gun.width / 2 , gun.width / 2, gun.width /2 );
  pg.image(gun, 0,0,gun.width / 2, gun.width /2   );
 
 
  // SCENARIO 1: faceList is empty
  if (faceList.isEmpty()) {
    // Just make a Face object for every face Rectangle
    for (int i = 0; i < faces.length; i++) {
      faceList.add(new Face(faces[i].x,faces[i].y,faces[i].width,faces[i].height));
    }
  // SCENARIO 2: We have fewer Face objects than face Rectangles found from OPENCV
  } else if (faceList.size() <= faces.length) {
    boolean[] used = new boolean[faces.length];
    // Match existing Face objects with a Rectangle
    for (int x = 0; x < faceList.size(); x++) {
       Face f  = (Face) faceList.get(x);
       // Find faces[index] that is closest to face f
       // set used[index] to true so that it can't be used twice
       float record = 50000;
       int index = -1;
       for (int i = 0; i < faces.length; i++) {
         float d = dist(faces[i].x,faces[i].y,f.r.x,f.r.y);
         if (d < record && !used[i]) {
           record = d;
           index = i;
         } 
       }
       // Update Face object location
       used[index] = true;
       f.update(faces[index]);
       f.available = false;
    }
    // Add any unused faces
    for (int i = 0; i < faces.length; i++) {
      if (!used[i]) {
        faceList.add(new Face(faces[i].x,faces[i].y,faces[i].width,faces[i].height));
      }
    }
  // SCENARIO 3: We have more Face objects than face Rectangles found
  } else {
    // All Face objects start out as available
    for (int x = 0; x < faceList.size();  x++) {
      Face f  = (Face) faceList.get(x);
      f.available = true;
    } 
    // Match Rectangle with a Face object
    for (int i = 0; i < faces.length; i++) {
      // Find face object closest to faces[i] Rectangle
      // set available to false
       float record = 50000;
       int index = -1;
       for (int j = 0; j < faceList.size(); j++) {
         Face f = (Face) faceList.get(j);
         float d = dist(faces[i].x,faces[i].y,f.r.x,f.r.y);
         if (d < record && f.available) {
           record = d;
           index = j;
         } 
       }
       // Update Face object location
       Face f = (Face) faceList.get(index);
       f.available = false;
       f.update(faces[i]);
    } 
    // Start to kill any left over Face objects
    for (int x = 0; x < faceList.size(); x++) {
       Face f  = (Face) faceList.get(x);
      if (f.available) {
        f.countDown();
        if (f.dead()) {
          if(f.id == target){
             target = -1; 
          }
          f.delete = true;
          faceList.remove(f);
        } 
      }
    } 
  }



  
  for (int i = 0; i < faceList.size(); i++) {
      Face f = (Face)  faceList.get(i);
      if (! f.delete) {
        f.display();
      }
  }  
  
  
  
  for (int i = 0; i < faceList.size(); i++) {
    Face f = (Face) faceList.get(i);
    if(target == -1 && facesProgress[f.id] == 0){
      target = f.id;
    }
    if(facesProgress[f.id] <= 80){
      facesProgress[f.id]++;
    }
    if(f.id == target){
      targetImage = new PImage(50, 50);
      targetImage.copy(video, f.r.x, f.r.y, f.r.width, f.r.height, 0, 0, 50 , 50);
      targetImage.filter(POSTERIZE, 8);
      
      if(currentTargetPositive){
        pg.image(targetReticuleBright, f.r.x + (f.r.width / 2) - 25, f.r.y + (f.r.height / 2) -25, 50, 50);
      }
      else {
        pg.image(targetReticule, f.r.x + (f.r.width / 2) - 25, f.r.y + (f.r.height / 2) -25, 50, 50);
      }
    }
  }
    
    
 
  if(faces.length > 0){
    pg.fill(255);
    pg.textSize(12);
    if(target != -1 ){
      pg.text("Target Acquired", 10, tvheight - 20);
    }
  }
  
  
  
  fft.window(FFT.HAMMING);


 loudestFreqAmp = 0;
 pg.strokeWeight(1);
 // draw the waveforms
 pg.stroke(255,255,255, 80);
 pg.line(5,5,5, 25);
 
   for(int i = 0; i < in.bufferSize() - 1; i+=30)
  {
  
  pg.line(5 + i / 30, 15 + in.left.get(i)*30, 5 + i / 30 + 1, 15 + in.left.get(i+1)*30);
  pg.line(5 + i / 30, 15 + in.right.get(i)*30, 5 + i / 30 + 1, 15 + in.right.get(i+1)*30);
  }
 
 pg.stroke(255,255,255, 100);
 pg.fill(255, 255, 255, 100);
 pg.textSize(6);
 pg.text("Audio engine: on",3,35);
 fft.forward(in.mix);
  
  
  pg.stroke(255,255,255, 80);
  pg.fill(255, 255, 255, 80);
  pg.textSize(6);
  pg.text("========", 5, 90); 
  for(int i = 0; i <= 6; i++){
    pg.text(random(0,1), 3, 100 + (i * 10)); 
  }
  
  
  if(target != -1){
       //tint(255, 255, 255, 100);
       pg.image(targetImage, tvwidth - targetImage.width , 0);//width - targetImage.width, height - targetImage.height);
       pg.stroke(255,255,255, 80);
       pg.fill(255, 255, 255, 80);
       pg.textSize(6);
       pg.text("Analyzing target database:", tvwidth - 130, 10);
       String bar = "|";
       for(int i = 0; i <= 60; i+=5){
         if( i < facesProgress[target] ){
           bar = bar + "="; 
         }
       }
       if (facesProgress[target] == 70 ){
         currentTargetPositive = int(random(1, 100)) < 100;
       }
       
       if ( facesProgress[target] >= 70 ){
         if(currentTargetPositive){
           pg.text("Terminate",  tvwidth - targetImage.width + 10, 20);
         }
         else {  
           pg.text("Negative",  tvwidth - targetImage.width + 10, 20); 
         }
       }
       
       
       
       if ( facesProgress[target] >= 80 ){
         target = -1;
         targetImage = null;
         currentTargetPositive = false;
       }
       pg.text(bar, tvwidth - 130, 20);
       pg.text("|", tvwidth - 60, 20);
       
       
       if ( target != -1 && currentTargetPositive && (facesProgress[target] == 77 || facesProgress[target] == 79)){
         pg.fill(255,255,255,80);
         pg.rect(0, 0, displayWidth, displayHeight);
       }
    }
    pg.endDraw();
    image(pg, 0, 0, displayWidth, displayHeight);

}

void captureEvent(Capture c) {
  c.read();
}


int powerUpCounter = 256;


void stop(){
   // always close Minim audio classes when you are done with them
   in.close();
   minim.stop();  
   super.stop();
}




