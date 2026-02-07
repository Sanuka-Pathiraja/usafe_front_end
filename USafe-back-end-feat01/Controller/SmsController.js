import { sendSingleSMS, sendBulkSameSMS, checkBalance } from "../CallFeat/quicksend.js";

const DISABLE_SMS = process.env.DISABLE_SMS === "true";

export async function sendSms(req, res) {
  if (DISABLE_SMS) {
    return res.status(503).json({
      message: "SMS feature is disabled (DISABLE_SMS=true)",
    });
  }

  try {
    const senderID = process.env.SOS_SENDER_ID || "QKSendDemo";
    const msg = req.body?.message || process.env.SOS_MESSAGE || "🚨 SOS! Immediate help needed.";
    const bodyNumbers = Array.isArray(req.body?.numbers) ? req.body.numbers : null;
    const envNumbers = (process.env.SOS_SMS_TO || "")
      .split(",")
      .map((n) => n.trim())
      .filter(Boolean);
    const numbers = bodyNumbers && bodyNumbers.length > 0 ? bodyNumbers : envNumbers;

    if (!numbers || numbers.length === 0) {
      return res.status(500).json({
        message: "Server configuration error: SOS_SMS_TO is not set in .env and no numbers provided",
      });
    }

    const response =
      numbers.length > 1
        ? await sendBulkSameSMS(numbers, msg, senderID)
        : await sendSingleSMS(numbers[0], msg, senderID);

    return res.status(200).json({
      message: "SOS SMS sent successfully",
      data: response,
      targets: numbers,
    });
  } catch (error) {
    console.error("SMS failed:", error.message);
    return res.status(500).json({
      message: "Failed to send SOS SMS",
      error: error.message,
    });
  }
}

export async function getBalance(req, res) {
  try {
    const balance = await checkBalance();
    return res.status(200).json({
      message: "Balance retrieved",
      data: balance,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Failed to check balance",
      error: error.message,
    });
  }
}
