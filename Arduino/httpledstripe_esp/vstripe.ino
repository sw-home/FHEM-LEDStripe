// Parameter 1 = number of pixels in strip
// Parameter 2 = Arduino pin number (most are valid)
// Parameter 3 = pixel type flags, add together as needed:
//   NEO_KHZ800  800 KHz bitstream (most NeoPixel products w/WS2812 LEDs)
//   NEO_KHZ400  400 KHz (classic 'v1' (not v2) FLORA pixels, WS2811 drivers)
//   NEO_GRB     Pixels are wired for GRB bitstream (most NeoPixel products)
//   NEO_RGB     Pixels are wired for RGB bitstream (v1 FLORA pixels, not v2)
Adafruit_NeoPixel strip1 = Adafruit_NeoPixel(NUMPIXELS1, LEDPIN1, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel strip2 = Adafruit_NeoPixel(NUMPIXELS2, LEDPIN2, NEO_GRB + NEO_KHZ800);

// Initialize all pixels to 'off'
void stripe_setup() {
  strip1.begin();
  strip2.begin();
  stripe_show(); 
}

void stripe_show() {
  strip1.show(); 
  strip2.show(); 
}

void stripe_setPixelColor(uint16_t pixel, uint32_t color) {
  if(pixel < NUMPIXELS1) {
    strip1.setPixelColor(NUMPIXELS1-1-pixel, color);
  } else {
    strip2.setPixelColor(pixel-NUMPIXELS1, color);
  }
}

uint32_t stripe_getPixelColor(uint16_t pixel) {
  if(pixel < NUMPIXELS1) {
    return strip1.getPixelColor(NUMPIXELS1-1-pixel);
  } else {
    return strip2.getPixelColor(pixel-NUMPIXELS1);
  }
}

void stripe_setBrightness(uint8_t b) {
  strip1.setBrightness(b);
  strip2.setBrightness(b);
}

uint16_t stripe_numPixels() {
  return NUMPIXELS1+NUMPIXELS2;
}

uint32_t stripe_color(uint8_t r, uint8_t g, uint8_t b) {
  return ((uint32_t)r << 16) | ((uint32_t)g <<  8) | b;
}

