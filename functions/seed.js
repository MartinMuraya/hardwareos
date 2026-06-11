const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid");

admin.initializeApp({
  projectId: "hardwareos-saas" // your project ID
});

const db = admin.firestore();

// Helpers for random data
function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomElement(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

const categories = ["Cement", "Pipes & Plumbing", "Paint", "Hardware & Tools", "Steel & Metals", "Timber"];
const productBases = {
  "Cement": ["Bamburi Cement 50kg", "Blue Triangle Cement 50kg", "Rhino Cement 50kg", "Simba Cement 50kg"],
  "Pipes & Plumbing": ["PVC Pipe 1 inch", "PVC Pipe 2 inch", "PPR Pipe 3/4 inch", "Gate Valve 1 inch", "Elbow Joint", "Tee Joint"],
  "Paint": ["Crown Silk Vinyl 4L", "Crown Silk Vinyl 20L", "Duracoat Emulsion 4L", "Basco Gloss 1L", "Paint Brush 2 inch", "Paint Roller"],
  "Hardware & Tools": ["Roofing Nails 1kg", "Steel Nails 2kg", "Claw Hammer", "Measuring Tape 5m", "Hacksaw", "Wheelbarrow"],
  "Steel & Metals": ["D10 Steel Bar", "D12 Steel Bar", "Y16 Steel Bar", "Binding Wire 1 roll", "Iron Sheet 3m"],
  "Timber": ["Timber 2x2", "Timber 2x4", "Timber 1x8", "MDF Board", "Plywood"]
};

async function seedData() {
  console.log("Fetching a business ID to attach data to...");
  const businessesSnap = await db.collection("businesses").limit(1).get();
  
  if (businessesSnap.empty) {
    console.error("No businesses found! Please create a business in the app first.");
    process.exit(1);
  }
  
  const businessId = businessesSnap.docs[0].id;
  console.log(`Using Business ID: ${businessId}`);
  
  const batchArray = [];
  let currentBatch = db.batch();
  let operationCounter = 0;

  function commitBatchOp() {
    operationCounter++;
    if (operationCounter === 500) {
      batchArray.push(currentBatch.commit());
      currentBatch = db.batch();
      operationCounter = 0;
    }
  }

  // 1. Generate 250 Products
  console.log("Generating products...");
  const generatedProducts = [];
  for (let i = 0; i < 250; i++) {
    const category = randomElement(categories);
    const nameBase = randomElement(productBases[category]);
    const name = `${nameBase} (Variant ${i + 1})`;
    
    const buyingPrice = randomInt(100, 3000);
    const sellingPrice = buyingPrice + randomInt(50, 500);
    const quantity = randomInt(10, 500);
    const minStockLevel = randomInt(5, 20);

    const docRef = db.collection("products").doc();
    const product = {
      id: docRef.id,
      businessId,
      name,
      category,
      sku: `SKU-${1000 + i}`,
      buyingPrice,
      sellingPrice,
      quantity,
      minStockLevel,
      supplierId: "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    currentBatch.set(docRef, product);
    generatedProducts.push(product);
    commitBatchOp();
  }

  // 2. Generate 300 Sales
  console.log("Generating sales...");
  const paymentMethods = ["cash", "mpesa", "card", "credit"];
  
  // Distribute over the last 30 days
  const now = new Date();
  
  for (let i = 0; i < 300; i++) {
    const saleDate = new Date(now.getTime() - randomInt(0, 30) * 24 * 60 * 60 * 1000 - randomInt(0, 24) * 60 * 60 * 1000);
    const itemCount = randomInt(1, 5);
    const items = [];
    let total = 0;
    let profit = 0;
    
    for (let j = 0; j < itemCount; j++) {
      const prod = randomElement(generatedProducts);
      const qty = randomInt(1, 10);
      items.push({
        productId: prod.id,
        name: prod.name,
        quantity: qty,
        unitPrice: prod.sellingPrice,
        subtotal: prod.sellingPrice * qty
      });
      total += prod.sellingPrice * qty;
      profit += (prod.sellingPrice - prod.buyingPrice) * qty;
    }

    const docRef = db.collection("sales").doc();
    currentBatch.set(docRef, {
      id: docRef.id,
      businessId,
      receiptNumber: `REC-${10000 + i}`,
      items,
      total,
      profit,
      paymentMethod: randomElement(paymentMethods),
      status: "completed",
      customerId: "",
      soldBy: "Seeding Script",
      createdAt: admin.firestore.Timestamp.fromDate(saleDate)
    });
    commitBatchOp();
  }

  // 3. Generate 100 Expenses
  console.log("Generating expenses...");
  const expenseCategories = ["Transport", "Meals", "Utilities", "Salaries", "Rent", "Maintenance"];
  for (let i = 0; i < 100; i++) {
    const expDate = new Date(now.getTime() - randomInt(0, 30) * 24 * 60 * 60 * 1000);
    const category = randomElement(expenseCategories);
    const docRef = db.collection("expenses").doc();
    currentBatch.set(docRef, {
      id: docRef.id,
      businessId,
      amount: randomInt(500, 15000),
      category,
      description: `Payment for ${category} - Seeded Data`,
      recordedBy: "Seeding Script",
      receiptUrl: null,
      createdAt: admin.firestore.Timestamp.fromDate(expDate)
    });
    commitBatchOp();
  }

  // Commit remaining
  if (operationCounter > 0) {
    batchArray.push(currentBatch.commit());
  }

  console.log("Committing batches to Firestore...");
  await Promise.all(batchArray);
  console.log("✅ Seed complete! Inserted ~250 products, ~300 sales, ~100 expenses.");
}

seedData().catch(e => console.error(e));
