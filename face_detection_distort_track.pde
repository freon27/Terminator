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

int w=320;
int h=240;
PImage tvscreen;
PImage TVOverlay;
PImage tvnoise;
PImage targetImage;
PImage gun;


int target;

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
    noFill();
      stroke(255,255,255,timer * 2);
      strokeWeight(2);
      // right line
      line(r.x + r.width , r.y, r.x + r.width, r.y + r.height);
      // top line
      line(r.x, r.y, r.x + r.width, r.y);
      stroke(255,255,255, timer * 2);
      fill(255, 255, 255, 80);
      textSize(8);
      text("Unknown agent: " + id, r.x + r.width + 20, r.y + 10);
      
      
      if (available){
          text("Tracking lost", r.x + r.width + 20, r.y + 30);
      }
      else if(facesProgress[id] >= 30){
        text(insults[insult1], r.x + r.width + 20, r.y + 30);
        text(insults[insult2], r.x + r.width + 20, r.y + 50);
        text("Threat level: " + threatLevel + "%", r.x + r.width + 20, r.y + 70);
      }
     else {
       text("Assessing threat level", r.x + r.width + 20, r.y + 30);
       text(symbols[facesProgress[id] % 4], r.x + r.width + 20, r.y + 50);
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
  
  
  size(640, 480);
  video = new Capture(this, 640/2, 480/2);
  opencv = new OpenCV(this, 640/2, 480/2);
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);  

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
  background(0);
  scale(2);
  opencv.loadImage(video);

  image(video, 0, 0 );
  tvscreen = video.get();
    
  renderDistort();
  
  tint(255,100,100, 100);
  
  fill(100,100,100,60);
  noStroke();
  strokeWeight(0);
  Rectangle[] faces = opencv.detect();
  println(faces.length);
  
  
 
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
    if(target == 0){
      targetImage = new PImage(50, 50);
      targetImage.copy(video, f.r.x, f.r.y, f.r.width, f.r.height, 0, 0, 50 , 50);
      targetImage.filter(POSTERIZE, 8);
      target = f.id;
    }
    if(facesProgress[f.id] < 70){
      facesProgress[f.id]++;
    } 
  }
    
/*println(faces[i].x + "," + faces[i].y);
    if(i == -1){
      float targetDiameter = faces[i].width * 1.2;
      beginShape();
      ellipse(faces[i].x + (faces[i].width / 2), faces[i].y + (faces[i].height / 2), targetDiameter, targetDiameter);
      beginContour();
      fill(0,0,0,100);
      ellipse(faces[i].x + (faces[i].width / 2), faces[i].y + (faces[i].height / 2), targetDiameter * 0.75, targetDiameter * 0.75);
      endContour();
      fill(100,100,100,50);
      ellipse(faces[i].x + (faces[i].width / 2), faces[i].y + (faces[i].height / 2), targetDiameter * 0.70, targetDiameter * 0.70);
      fill(0,0,0,100);
      rect(faces[i].x + (faces[i].width * 0.07), faces[i].y + ((faces[i].height / 2) - 2 ), targetDiameter * 0.73, 4);
      rect(faces[i].x + (faces[i].width / 2), faces[i].y + ((faces[i].height / 2) - 5 ), 2, 10);
      rect(faces[i].x + (faces[i].width / 2), faces[i].y - (faces[i].width / 2), 2, 10);
      endShape();
    }
 */
  if(faces.length > 0){
    fill(255);
    textSize(12);
    text("Target Acquired", 10, tvheight - 10);
  }
  
  
  
  fft.window(FFT.HAMMING);

/*
 for(int i = 0; i < fft.specSize(); i++)
 {
   // draw the line for frequency band i, scaling it by 4 so we can
   //see it a bit better
   //line(i, height, i, height - fft.getBand(i)*4);
   if (fft.getBand(i) > loudestFreqAmp && fft.getBand(i) > 10)
   {
     loudestFreqAmp = fft.getBand(i);
     loudestFreq = i * 4;
     //sine.setFreq(loudestFreq);
     fill(loudestFreq * 10, 255 - loudestFreq, loudestFreq * 20, 128 );
     if(loudestFreq < 25)
     {
       rect(random(0,100), random(0,50), loudestFreqAmp, loudestFreqAmp);
     }
     else
     {
       ellipse(random(0,100), random(0,50), loudestFreqAmp, loudestFreqAmp);
     }
     timerCounter = 0;
   }
 }*/
 loudestFreqAmp = 0;
 strokeWeight(1);
 // draw the waveforms
 stroke(255,255,255, 80);
 line(5,5,5, 25);
 
   for(int i = 0; i < in.bufferSize() - 1; i+=30)
  {
  
  line(5 + i / 30, 15 + in.left.get(i)*30, 5 + i / 30 + 1, 15 + in.left.get(i+1)*30);
  line(5 + i / 30, 15 + in.right.get(i)*30, 5 + i / 30 + 1, 15 + in.right.get(i+1)*30);
  }
 
 stroke(255,255,255, 100);
 fill(255, 255, 255, 100);
 textSize(6);
 text("Audio engine: on",3,35);
 fft.forward(in.mix);
  
  
  stroke(255,255,255, 80);
  fill(255, 255, 255, 80);
  textSize(6);
  text("========", 5, 90); 
  for(int i = 0; i <= 6; i++){
    text(random(0,1), 3, 100 + (i * 10)); 
  }
  
  
  if(target != 0){
       //tint(255, 255, 255, 100);
       image(targetImage, tvwidth - targetImage.width , 0);//width - targetImage.width, height - targetImage.height);
       stroke(255,255,255, 80);
       fill(255, 255, 255, 80);
       textSize(6);
       text("Analyzing target database:", tvwidth - 130, 10);
       String bar = "|";
       for(int i = 0; i <= 70; i+=5){
         if( i < facesProgress[target] ){
           bar = bar + "="; 
         }
       }
       text(bar, tvwidth - 130, 20);
       text("|", tvwidth - 60, 20);
    }
      
    image(gun, 0, 0);

}

void captureEvent(Capture c) {
  c.read();
}


int powerUpCounter = 256;

void scaleIt(float amountA, float amountB, int valueA, int valueB, int valueC, int valueD){
  if (lerpAmount < 1)
  {
    lerpAmount += amountA;
    powerUpCounter = (int)lerp(valueA,valueB,lerpAmount);
  }

  if (lerpScale < 1)
  {
    lerpScale += amountB;
    tvheight = (int)lerp(valueC,valueD,lerpScale);
  }  

  // final horiontal line shrink on power off
  if (!tvstate && tvheight < 100)
  {
    if (lerpShrink < 1)
    {
      tvwidth = (int)lerp(width,1,lerpShrink);
      lerpShrink += .09;

      
      
    }
  }
}

// RGB Distort
void renderDistort() {
  int i = 0;

  int offRed  = (int)(Math.random() * 2) * 2;
  int offGreen= (int)(Math.random() * 2) * 2;
  int offBlue = (int)(Math.random() * 2) * 2;

  if (barY2 > h) {
    barY1=10 -40;
    barY2=30 -40;
  }

  barY1 +=2;
  barY2 +=2;

  if (tvstate)
    scaleIt(0.02,0.2,156,0,2,tvscreen.height);  // turning on 
  else
    scaleIt(0.1,0.2,0,-400,tvscreen.height,1);   // turning off

  // dark vs light flicker + gradual fade in
  int flicker = (offBlue*8)+powerUpCounter; 

  for ( int y = 1; y < h; y++ ) {

    // vertically moving horizonal strip + flicker
    int colDiv = ( y < barY2 && y > barY1 ) ? 20+flicker : flicker; 

    // horizontal scanlines
    int strips=(y&1)*64 +colDiv; 

    // grab a random line of precalculated TV noise
    int noiseLine = int(random(0,tvheight)) * width;

    for ( int x=0; x < w; x++ ) {
      int imagePixelR = tvscreen.pixels[i +offRed] >> 16 & 0xFF ;
      int imagePixelG = tvscreen.pixels[i +offGreen] >> 8 & 0xFF ;
      int imagePixelB = tvscreen.pixels[i +offBlue] & 0xFF ; 
      int processEffect = -strips-ppx[noiseLine /2 +x];
      tvnoise.pixels[i++] =  color(imagePixelR+processEffect, imagePixelG+processEffect, imagePixelB+processEffect);      
    }
  }
  tvnoise.updatePixels();

  //  image(tvnoise,0,0,tvscreen.width,270);
  tint(255, 50);
  image(tvnoise,(tvscreen.width-tvwidth/2)-tvscreen.width/2,(tvscreen.height-tvheight/2)-tvscreen.height/2,tvwidth,tvheight);
}


void stop(){
   // always close Minim audio classes when you are done with them
   in.close();
   minim.stop();  
   super.stop();
}




