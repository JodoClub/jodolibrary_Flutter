/**
 * JODO LIBRARY - ENQUIRY & PARTNER ONBOARDING GOOGLE APPS SCRIPT WEBHOOK
 * ---------------------------------------------------------------------
 * This script accepts enquiries from the Jodo Library App and saves them
 * into a Google Sheet in real time.
 *
 * HOW TO SETUP IN GOOGLE SHEETS:
 * 1. Open Google Sheets (create a new blank spreadsheet or open existing).
 * 2. Click on "Extensions" -> "Apps Script".
 * 3. Delete any existing code and paste this entire file content.
 * 4. Click the Save icon (Ctrl+S or disk icon).
 * 5. Click "Deploy" (blue button at top right) -> "New deployment".
 * 6. Click the gear icon next to "Select type" and select "Web app".
 * 7. Set the following options:
 *    - Description: "Jodo Library Enquiry Webhook"
 *    - Execute as: "Me" (your email)
 *    - Who has access: "Anyone" (IMPORTANT: Allows app submissions without Google login)
 * 8. Click "Deploy", review and grant permissions (Click Advanced -> Go to ... (unsafe)).
 * 9. Copy the generated "Web app URL" (e.g., https://script.google.com/macros/s/.../exec).
 * 10. The webhook is now LIVE and will auto-generate the header row on first submission!
 */

function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    // Wait up to 30 seconds for concurrent write locks
    lock.waitLock(30000);

    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getActiveSheet();

    // Auto-create and format header row on empty sheets
    if (sheet.getLastRow() === 0) {
      sheet.appendRow([
        "Timestamp",
        "Full Name",
        "User Type",
        "Enquiry Type",
        "Mobile / WhatsApp",
        "Email",
        "Address / City",
        "Enquiry Message",
        "Status"
      ]);

      var headerRange = sheet.getRange(1, 1, 1, 9);
      headerRange.setFontWeight("bold");
      headerRange.setBackground("#0F4DD2");
      headerRange.setFontColor("#FFFFFF");
      sheet.setFrozenRows(1);
    }

    // Parse incoming payload (supports both JSON postData and URL-encoded forms)
    var data = {};
    if (e && e.postData && e.postData.contents) {
      try {
        data = JSON.parse(e.postData.contents);
      } catch (err) {
        data = e.parameter || {};
      }
    } else if (e && e.parameter) {
      data = e.parameter;
    }

    var timestamp = data.dateTime || Utilities.formatDate(new Date(), "Asia/Kolkata", "yyyy-MM-dd HH:mm:ss");
    var name = data.fullName || data.name || "N/A";
    var userType = data.userType || "Other";
    var enquiryType = data.enquiryType || "General Enquiry";
    var phone = data.mobile || data.phone || data.whatsapp || "";
    var email = data.email || "";
    var address = data.address || data.city || "";
    var message = data.message || data.enquiryMessage || "";
    var status = "New Enquiry";

    // Append the row
    sheet.appendRow([
      timestamp,
      name,
      userType,
      enquiryType,
      phone,
      email,
      address,
      message,
      status
    ]);

    var newRow = sheet.getLastRow();

    // Auto-align and wrap message
    sheet.getRange(newRow, 1, 1, 9).setVerticalAlignment("middle");
    sheet.getRange(newRow, 8).setWrap(true);

    return ContentService.createTextOutput(JSON.stringify({
      "success": true,
      "message": "Enquiry submitted successfully!",
      "row": newRow
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      "success": false,
      "error": error.toString(),
      "message": "Failed to record enquiry"
    })).setMimeType(ContentService.MimeType.JSON);

  } finally {
    lock.releaseLock();
  }
}

function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    "status": "online",
    "service": "Jodo Library Enquiry Webhook",
    "timestamp": new Date().toISOString()
  })).setMimeType(ContentService.MimeType.JSON);
}
