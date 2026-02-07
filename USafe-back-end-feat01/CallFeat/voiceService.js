import { Vonage } from "@vonage/server-sdk";
import fs from "fs";

export default async function makeOutboundCall(toOverride) {
  if (!process.env.VONAGE_PRIVATE_KEY) {
    throw new Error("❌ VONAGE_PRIVATE_KEY is missing in .env");
  }

  const privateKeyPath = process.env.VONAGE_PRIVATE_KEY;
  if (!fs.existsSync(privateKeyPath)) {
    throw new Error(`❌ Private key file not found at: ${privateKeyPath}`);
  }

  if (!process.env.VONAGE_APPLICATION_ID) {
    throw new Error("❌ VONAGE_APPLICATION_ID is missing in .env");
  }

  const vonage = new Vonage({
    applicationId: process.env.VONAGE_APPLICATION_ID,
    privateKey: fs.readFileSync(privateKeyPath),
  });

  const to = (toOverride || process.env.SOS_CALL_TO || "").trim();
  const text = process.env.SOS_CALL_TEXT || "Hello! This is a test call from USafe.";

  if (!to) {
    throw new Error("❌ Missing call target. Set SOS_CALL_TO in .env or pass a 'to' number.");
  }

  if (!process.env.VONAGE_FROM_NUMBER) {
    throw new Error("❌ VONAGE_FROM_NUMBER is missing in .env");
  }

  try {
    console.log("📞 Attempting to call:", to);
    console.log("📞 From number:", process.env.VONAGE_FROM_NUMBER);

    const response = await vonage.voice.createOutboundCall({
      to: [{ type: "phone", number: to }],
      from: { type: "phone", number: process.env.VONAGE_FROM_NUMBER },
      ncco: [
        {
          action: "talk",
          language: "en-US",
          style: 0,
          premium: false,
          text,
        },
      ],
    });

    console.log("✅ Call initiated:", response);
    return response;
  } catch (error) {
    console.error("❌ Vonage API Error:", error.response?.data || error.message);
    throw error;
  }
}
