// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Notification pour nouveau message
exports.sendMessageNotification = functions.firestore
    .document('messages/{messageId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const recipientId = data.recipientId;
        
        if (!recipientId) return;
        
        try {
            // Récupérer le token FCM du destinataire
            const userDoc = await admin.firestore().collection('users').doc(recipientId).get();
            const token = userDoc.data()?.fcmToken;
            
            if (token) {
                const payload = {
                    notification: {
                        title: `📬 ${data.senderName}`,
                        body: data.content.length > 100 ? data.content.substring(0, 100) + '...' : data.content,
                    },
                    data: {
                        type: 'message',
                        messageId: snap.id,
                        senderId: data.senderId,
                        senderName: data.senderName,
                        senderRole: data.senderRole,
                    },
                };
                
                await admin.messaging().sendToDevice(token, payload);
                console.log(`✅ Notification envoyée à ${recipientId}`);
            }
        } catch (error) {
            console.error('❌ Erreur:', error);
        }
    });

// Notification pour nouvelle note
exports.sendGradeNotification = functions.firestore
    .document('grades/{gradeId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const studentName = data.studentName;
        const subject = data.subject;
        const score = data.score;
        const maxScore = data.maxScore;
        
        try {
            // Récupérer l'étudiant
            const studentQuery = await admin.firestore()
                .collection('students')
                .where('fullName', '==', studentName)
                .limit(1)
                .get();
            
            if (!studentQuery.empty) {
                const student = studentQuery.docs[0];
                const studentId = student.id;
                const parentId = student.data().parentUserId;
                
                const payload = {
                    notification: {
                        title: `📝 Nouvelle note en ${subject}`,
                        body: `${score}/${maxScore} - ${studentName}`,
                    },
                    data: {
                        type: 'grade',
                        subject: subject,
                        score: score.toString(),
                    },
                };
                
                // Notifier l'élève
                const studentToken = (await admin.firestore().collection('users').doc(studentId).get()).data()?.fcmToken;
                if (studentToken) {
                    await admin.messaging().sendToDevice(studentToken, payload);
                }
                
                // Notifier le parent
                if (parentId) {
                    const parentToken = (await admin.firestore().collection('users').doc(parentId).get()).data()?.fcmToken;
                    if (parentToken) {
                        await admin.messaging().sendToDevice(parentToken, payload);
                    }
                }
            }
        } catch (error) {
            console.error('❌ Erreur:', error);
        }
    });

// Notification pour absence
exports.sendAbsenceNotification = functions.firestore
    .document('attendances/{attendanceId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        
        if (data.status !== 'absent') return;
        
        const studentName = data.studentName;
        const date = data.date ? data.date.toDate() : new Date();
        const formattedDate = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
        
        try {
            // Récupérer le parent
            const studentQuery = await admin.firestore()
                .collection('students')
                .where('fullName', '==', studentName)
                .limit(1)
                .get();
            
            if (!studentQuery.empty) {
                const parentId = studentQuery.docs[0].data().parentUserId;
                
                if (parentId) {
                    const parentToken = (await admin.firestore().collection('users').doc(parentId).get()).data()?.fcmToken;
                    
                    if (parentToken) {
                        const payload = {
                            notification: {
                                title: `⚠️ Absence signalée`,
                                body: `${studentName} était absent le ${formattedDate}`,
                            },
                            data: {
                                type: 'attendance',
                                studentName: studentName,
                                date: formattedDate,
                            },
                        };
                        
                        await admin.messaging().sendToDevice(parentToken, payload);
                        console.log(`✅ Notification d'absence envoyée au parent de ${studentName}`);
                    }
                }
            }
        } catch (error) {
            console.error('❌ Erreur:', error);
        }
    });

// Notification pour nouvel examen
exports.sendExamNotification = functions.firestore
    .document('online_exams/{examId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const className = data.className;
        const examTitle = data.title;
        const startDate = data.startDate ? data.startDate.toDate() : new Date();
        const formattedDate = `${startDate.getDate()}/${startDate.getMonth() + 1}/${startDate.getFullYear()} à ${startDate.getHours()}:${startDate.getMinutes().toString().padStart(2, '0')}`;
        
        try {
            // Récupérer tous les étudiants de la classe
            const studentsSnapshot = await admin.firestore()
                .collection('students')
                .where('className', '==', className)
                .get();
            
            const payload = {
                notification: {
                    title: `📚 Nouvel examen: ${examTitle}`,
                    body: `Début le ${formattedDate}`,
                },
                data: {
                    type: 'exam',
                    examTitle: examTitle,
                    examId: snap.id,
                },
            };
            
            for (const studentDoc of studentsSnapshot.docs) {
                const studentId = studentDoc.id;
                const parentId = studentDoc.data().parentUserId;
                
                // Notifier l'élève
                const studentToken = (await admin.firestore().collection('users').doc(studentId).get()).data()?.fcmToken;
                if (studentToken) {
                    await admin.messaging().sendToDevice(studentToken, payload);
                }
                
                // Notifier le parent
                if (parentId) {
                    const parentToken = (await admin.firestore().collection('users').doc(parentId).get()).data()?.fcmToken;
                    if (parentToken) {
                        await admin.messaging().sendToDevice(parentToken, payload);
                    }
                }
            }
            
            console.log(`✅ Notification d'examen envoyée à la classe ${className}`);
        } catch (error) {
            console.error('❌ Erreur:', error);
        }
    });