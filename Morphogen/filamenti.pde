// --- DIRETTIVE DEL MANIFESTO: SETTINGS GLOBALI ---
int maxEdgeLen = 7;         
int minEdgeLen = 2;         
float repulsionRadius = 18;   
float repulsionForce = 1.2;   
float springForce = 0.25;      
float alignForce = 0.45;      

float noiseScale = 0.01;
float moldRadius = 0;         
float mouseRepulsion = 150;    

ArrayList<Node> path;
SpatialGrid spatialGrid;
boolean isPaused = false;

// --- MULTI-THREADING E LIVELLI ---
ArrayList<float[]> history;
boolean isSaving = false;      
String savedFilename = "";     

PGraphics liveCanvas; // Il nostro livello per l'accumulo della luce a schermo

void setup() {
  fullScreen();
  
  // Inizializziamo il livello visivo per la scia in tempo reale
  liveCanvas = createGraphics(width, height);
  liveCanvas.beginDraw();
  liveCanvas.background(5, 5, 8);
  liveCanvas.endDraw();
  
  moldRadius = min(width, height) * 0.35;
  
  path = new ArrayList<Node>();
  history = new ArrayList<float[]>(); 
  
  float radius = 10;
  for (int i = 0; i < 6; i++) {
    float angle = map(i, 0, 6, 0, TWO_PI);
    float x = width / 2.0 + cos(angle) * radius;
    float y = height / 2.0 + sin(angle) * radius;
    path.add(new Node(x, y));
  }
}

void draw() {
  // 1. GESTIONE DELL'INTERFACCIA E DELLE PAUSE
  if (isSaving) {
    image(liveCanvas, 0, 0); // Mostriamo l'opera sotto
    fill(5, 5, 8, 220);      // Velo scuro trasparente
    noStroke();
    rect(0, 0, width, height);
    
    fill(255);
    textSize(24);
    textAlign(CENTER, CENTER);
    text("⏳ SALVATAGGIO TIFF A2 IN CORSO (140 Megapixel) ⏳\nRidisegnando " + history.size() + " fotogrammi in background...\nNon toccare la tastiera e attendi il completamento.", width/2, height/2);
    return; 
  }

  if (!savedFilename.equals("")) {
    image(liveCanvas, 0, 0); 
    fill(5, 5, 8, 220); 
    noStroke();
    rect(0, 0, width, height);
    
    fill(0, 255, 150); 
    textSize(24);
    textAlign(CENTER, CENTER);
    text("✅ OPERA ESPORTATA CON SUCCESSO! ✅\nFile: " + savedFilename + "\nPremi la BARRA SPAZIATRICE per continuare.", width/2, height/2);
    return;
  }

  if (isPaused) {
    image(liveCanvas, 0, 0); // Se in pausa, continua a mostrare l'opera intatta
    return; 
  }
  
  // 2. LOGICA DI SIMULAZIONE (Fisica ed Emergenza)
  spatialGrid = new SpatialGrid(repulsionRadius);
  for (Node node : path) {
    spatialGrid.insert(node);
  }
  
  PVector mousePos = new PVector(mouseX, mouseY);
  
  for (int i = 0; i < path.size(); i++) {
    Node node = path.get(i);
    Node prevNode = path.get((i - 1 + path.size()) % path.size());
    Node nextNode = path.get((i + 1) % path.size());
    
    PVector springCenter = PVector.add(prevNode.pos, nextNode.pos).div(2);
    PVector attraction = PVector.sub(springCenter, node.pos).mult(springForce);
    PVector alignment = PVector.sub(springCenter, node.pos).mult(alignForce);
    
    PVector repulsion = new PVector(0, 0);
    ArrayList<Node> neighbors = spatialGrid.getNeighbors(node.pos, repulsionRadius);
    
    for (Node other : neighbors) {
      if (other != node && other != prevNode && other != nextNode) {
        float d = PVector.dist(node.pos, other.pos);
        if (d > 0 && d < repulsionRadius) {
          PVector pushForce = PVector.sub(node.pos, other.pos);
          pushForce.normalize();
          pushForce.mult(map(d, 0, repulsionRadius, repulsionForce, 0)); 
          repulsion.add(pushForce);
        }
      }
    }
    
    float angleToCenter = atan2(node.pos.y - height/2.0, node.pos.x - width/2.0);
    float noiseOffset = noise(cos(angleToCenter) + 1, sin(angleToCenter) + 1, frameCount * 0.005) * 150;
    float dynamicBoundary = moldRadius + noiseOffset;
    
    float distFromCenter = dist(node.pos.x, node.pos.y, width/2.0, height/2.0);
    PVector moldForce = new PVector(0, 0);
    
    if (distFromCenter > dynamicBoundary) {
      moldForce = PVector.sub(new PVector(width/2.0, height/2.0), node.pos);
      moldForce.normalize().mult(1.5); 
    }
    
    PVector humanForce = new PVector(0,0);
    if (mouseX > 0 && mouseX < width && mouseY > 0 && mouseY < height) {
      float mouseDist = PVector.dist(node.pos, mousePos);
      if (mouseDist < mouseRepulsion) {
         humanForce = PVector.sub(node.pos, mousePos);
         humanForce.normalize().mult(map(mouseDist, 0, mouseRepulsion, 3, 0));
      }
    }
    
    node.acc.add(attraction);
    node.acc.add(alignment);
    node.acc.add(repulsion);
    node.acc.add(moldForce);
    node.acc.add(humanForce);
  }
  
  for (int i = path.size() - 1; i >= 0; i--) {
    Node node = path.get(i);
    node.update();
    
    Node nextNode = path.get((i + 1) % path.size());
    float d = PVector.dist(node.pos, nextNode.pos);
    
    if (d > maxEdgeLen) {
      PVector midPoint = PVector.add(node.pos, nextNode.pos).div(2);
      path.add(i + 1, new Node(midPoint.x, midPoint.y));
    }
  }
  
  // 3. MEMORIA "MACCHINA DEL TEMPO" PER IL TIFF
  float[] currentFramePositions = new float[path.size() * 2];
  for (int i = 0; i < path.size(); i++) {
    currentFramePositions[i * 2] = path.get(i).pos.x;
    currentFramePositions[i * 2 + 1] = path.get(i).pos.y;
  }
  history.add(currentFramePositions);
  
  // 4. DISEGNO ACCUMULATIVO SUL LIVELLO INVISIBILE
  liveCanvas.beginDraw();
  liveCanvas.stroke(240, 248, 255, 12); // Trasparenza attiva! Accumulo di luce.
  liveCanvas.strokeWeight(1);
  liveCanvas.noFill();
  liveCanvas.beginShape();
  for (Node node : path) {
    liveCanvas.curveVertex(node.pos.x, node.pos.y);
  }
  if (path.size() > 1) {
    liveCanvas.curveVertex(path.get(0).pos.x, path.get(0).pos.y);
    liveCanvas.curveVertex(path.get(1).pos.x, path.get(1).pos.y);
  }
  liveCanvas.endShape();
  liveCanvas.endDraw();
  
  // 5. RENDERING FINALE A SCHERMO
  background(5, 5, 8); // Pulisce lo schermo base (previene artefatti)
  image(liveCanvas, 0, 0); // Stampa il livello con la scia sopra lo schermo
  
  if (path.size() > 4000) {
    noLoop();
    println("Limite nodi raggiunto.");
  }
}

// --- CONTROLLI ---
void keyPressed() {
  if (!savedFilename.equals("") && key == ' ') {
    savedFilename = "";
    return;
  }

  if (key == ' ' || key == 'p' || key == 'P') {
    isPaused = !isPaused;
  }
  
  if ((key == 's' || key == 'S') && !isSaving) {
    isSaving = true;
    isPaused = true; 
    thread("exportTiffInThread"); 
  }
  
  if (key == ESC) {
    exit();
  }
}

// --- ESPORTAZIONE IN BACKGROUND ---
void exportTiffInThread() {
  String filename = "FineArt_A2_Tracce_" + year() + nf(month(),2) + nf(day(),2) + "_" + nf(hour(),2) + nf(minute(),2) + nf(second(),2) + ".tif";
  
  int PRINT_W = 14031; 
  int PRINT_H = 9921;  
  
  PGraphics pg = createGraphics(PRINT_W, PRINT_H);
  float scaleFit = min((float)PRINT_W / width, (float)PRINT_H / height);
  float offsetX = (PRINT_W - (width * scaleFit)) / 2.0;
  float offsetY = (PRINT_H - (height * scaleFit)) / 2.0;
  
  pg.beginDraw();
  pg.background(5, 5, 8);
  pg.stroke(240, 248, 255, 12); 
  pg.strokeWeight(scaleFit * 0.7); 
  pg.noFill();
  
  for (float[] frameData : history) {
    pg.beginShape();
    for (int i = 0; i < frameData.length; i += 2) {
      float px = offsetX + frameData[i] * scaleFit;
      float py = offsetY + frameData[i+1] * scaleFit;
      pg.curveVertex(px, py);
    }
    if (frameData.length >= 4) {
      pg.curveVertex(offsetX + frameData[0] * scaleFit, offsetY + frameData[1] * scaleFit);
      pg.curveVertex(offsetX + frameData[2] * scaleFit, offsetY + frameData[3] * scaleFit);
    }
    pg.endShape();
  }
  
  pg.endDraw();
  pg.save(filename); 
  
  isSaving = false;
  savedFilename = filename;
}

// --- CLASSI INVARIATE ---
class Node { PVector pos, vel, acc; Node(float x, float y) { pos = new PVector(x, y); vel = new PVector(0, 0); acc = new PVector(0, 0); } void update() { vel.add(acc); vel.limit(1.5); pos.add(vel); vel.mult(0.6); acc.mult(0); } }
class SpatialGrid { float cellSize; java.util.HashMap<String, ArrayList<Node>> cells; SpatialGrid(float cellSize) { this.cellSize = cellSize; cells = new java.util.HashMap<String, ArrayList<Node>>(); } String getKey(float x, float y) { return floor(x / cellSize) + "," + floor(y / cellSize); } void insert(Node node) { String key = getKey(node.pos.x, node.pos.y); if (!cells.containsKey(key)) { cells.put(key, new ArrayList<Node>()); } cells.get(key).add(node); } ArrayList<Node> getNeighbors(PVector pos, float radius) { ArrayList<Node> neighbors = new ArrayList<Node>(); int searchCells = ceil(radius / cellSize); int cx = floor(pos.x / cellSize); int cy = floor(pos.y / cellSize); for (int x = -searchCells; x <= searchCells; x++) { for (int y = -searchCells; y <= searchCells; y++) { String key = (cx + x) + "," + (cy + y); if (cells.containsKey(key)) neighbors.addAll(cells.get(key)); } } return neighbors; } }
