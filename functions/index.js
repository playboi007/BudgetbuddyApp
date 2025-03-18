/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });*/


const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// Maintain category balance whenever a transaction is added or deleted
exports.updateCategoryBalance = functions.firestore
  .document('users/{userId}/categories/{categoryId}/transactions/{transactionId}')
  .onWrite(async (change, context) => {
    const { userId, categoryId } = context.params;
    
    // Get a reference to the category document
    const categoryRef = db.collection('users').doc(userId).collection('categories').doc(categoryId);
    
    // Run transaction to ensure data consistency
    return db.runTransaction(async (transaction) => {
      // Get all transactions for this category
      const transactionsSnapshot = await transaction.get(
        categoryRef.collection('transactions')
      );
      
      // Calculate the balance
      let balance = 0;
      transactionsSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.transactionType === 'deposit') {
          balance += data.amount;
        } else if (data.transactionType === 'withdrawal') {
          balance -= data.amount;
        }
      });
      
      // Update the category balance
      return transaction.update(categoryRef, { amount: balance });
    });
  });

// Pre-calculate and store monthly aggregations for quick report generation
exports.calculateMonthlySummary = functions.pubsub
  .schedule('0 0 1 * *') // Run on the 1st of every month
  .timeZone('UTC')
  .onRun(async (context) => {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    
    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();
    const lastMonth = new Date(now.toDate());
    lastMonth.setMonth(lastMonth.getMonth() - 1);
    lastMonth.setDate(1);
    lastMonth.setHours(0, 0, 0, 0);
    
    const endOfLastMonth = new Date(lastMonth);
    endOfLastMonth.setMonth(endOfLastMonth.getMonth() + 1);
    endOfLastMonth.setDate(0); // Last day of the month
    endOfLastMonth.setHours(23, 59, 59, 999);
    
    const monthKey = `${lastMonth.getFullYear()}-${(lastMonth.getMonth() + 1).toString().padStart(2, '0')}`;
    
    // Process each user
    const promises = usersSnapshot.docs.map(async (userDoc) => {
      const userId = userDoc.id;
      const userRef = db.collection('users').doc(userId);
      
      // Get all categories for this user
      const categoriesSnapshot = await userRef.collection('categories').get();
      
      // Initialize summary data
      const summary = {
        deposits: 0,
        withdrawals: 0,
        net: 0,
        byCategory: {}
      };
      
      // Process each category
      for (const categoryDoc of categoriesSnapshot.docs) {
        const categoryId = categoryDoc.id;
        const categoryName = categoryDoc.data().name;
        
        // Get transactions for this category in the last month
        const transactionsSnapshot = await userRef
          .collection('categories')
          .doc(categoryId)
          .collection('transactions')
          .where('date', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
          .where('date', '<=', admin.firestore.Timestamp.fromDate(endOfLastMonth))
          .get();
        
        // Initialize category summary
        summary.byCategory[categoryId] = {
          name: categoryName,
          deposits: 0,
          withdrawals: 0,
          net: 0
        };
        
        // Calculate totals
        transactionsSnapshot.forEach(doc => {
          const data = doc.data();
          
          if (data.transactionType === 'deposit') {
            summary.deposits += data.amount;
            summary.net += data.amount;
            summary.byCategory[categoryId].deposits += data.amount;
            summary.byCategory[categoryId].net += data.amount;
          } else if (data.transactionType === 'withdrawal') {
            summary.withdrawals += data.amount;
            summary.net -= data.amount;
            summary.byCategory[categoryId].withdrawals += data.amount;
            summary.byCategory[categoryId].net -= data.amount;
          }
        });
      }
      
      // Store the monthly summary
      const monthlySummaryRef = userRef.collection('monthlySummaries').doc(monthKey);
      batch.set(monthlySummaryRef, {
        year: lastMonth.getFullYear(),
        month: lastMonth.getMonth() + 1,
        deposits: summary.deposits,
        withdrawals: summary.withdrawals,
        net: summary.net,
        byCategory: summary.byCategory,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    // Wait for all user processing to complete
    await Promise.all(promises);
    
    // Commit the batch
    return batch.commit();
  });

// Update user's total savings stat
exports.updateUserTotalSavings = functions.firestore
  .document('users/{userId}/categories/{categoryId}')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    const userRef = db.collection('users').doc(userId);
    
    // Run transaction to ensure data consistency
    return db.runTransaction(async (transaction) => {
      // Get all categories for this user
      const categoriesSnapshot = await transaction.get(
        userRef.collection('categories')
      );
      
      // Calculate total savings
      let totalSavings = 0;
      categoriesSnapshot.forEach(doc => {
        const data = doc.data();
        totalSavings += data.amount || 0;
      });
      
      // Update the user document with the total savings
      return transaction.update(userRef, { 
        totalSavings: totalSavings,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });
    });
  });

// Generate weekly report summaries and notify users
exports.generateWeeklyReports = functions.pubsub
  .schedule('0 8 * * 1') // Run at 8 AM every Monday
  .timeZone('America/New_York')
  .onRun(async (context) => {
    // Get all users
    const usersSnapshot = await db.collection('users')
      .where('notificationsEnabled', '==', true)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('No users with notifications enabled');
      return null;
    }
    
    const now = admin.firestore.Timestamp.now().toDate();
    const oneWeekAgo = new Date(now);
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    
    const batch = db.batch();
    const messages = [];
    
    // Process each user
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const userRef = db.collection('users').doc(userId);
      
      // Get all transactions for this user in the last week
      const categoriesSnapshot = await userRef.collection('categories').get();
      
      let weeklyDeposits = 0;
      let weeklyWithdrawals = 0;
      
      // Process each category
      for (const categoryDoc of categoriesSnapshot.docs) {
        const categoryId = categoryDoc.id;
        
        // Get transactions for this category in the last week
        const transactionsSnapshot = await userRef
          .collection('categories')
          .doc(categoryId)
          .collection('transactions')
          .where('date', '>=', admin.firestore.Timestamp.fromDate(oneWeekAgo))
          .get();
        
        // Calculate totals
        transactionsSnapshot.forEach(doc => {
          const data = doc.data();
          
          if (data.transactionType === 'deposit') {
            weeklyDeposits += data.amount;
          } else if (data.transactionType === 'withdrawal') {
            weeklyWithdrawals += data.amount;
          }
        });
      }
      
      // Create weekly report
      const weeklyReportRef = userRef.collection('weeklyReports').doc();
      batch.set(weeklyReportRef, {
        startDate: admin.firestore.Timestamp.fromDate(oneWeekAgo),
        endDate: admin.firestore.Timestamp.fromDate(now),
        deposits: weeklyDeposits,
        withdrawals: weeklyWithdrawals,
        net: weeklyDeposits - weeklyWithdrawals,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Prepare notification message if user has token
      if (userData.fcmToken) {
        const netChange = weeklyDeposits - weeklyWithdrawals;
        const formattedNet = netChange.toFixed(2);
        const trend = netChange >= 0 ? 'increased' : 'decreased';
        
        messages.push({
          token: userData.fcmToken,
          notification: {
            title: 'Your Weekly Savings Report',
            body: `Your savings ${trend} by $${Math.abs(formattedNet)} this week.`
          },
          data: {
            type: 'weekly_report',
            reportId: weeklyReportRef.id
          }
        });
      }
    }
    
    // Commit the batch
    await batch.commit();
    
    // Send notifications if any
    if (messages.length > 0) {
      try {
        const messaging = admin.messaging();
        
        // Send in batches of 500 (FCM limit)
        const batches = [];
        for (let i = 0; i < messages.length; i += 500) {
          const batch = messages.slice(i, i + 500);
          batches.push(messaging.sendAll(batch));
        }
        
        await Promise.all(batches);
      } catch (error) {
        console.error('Error sending notifications:', error);
      }
    }
    
    return null;
  });

