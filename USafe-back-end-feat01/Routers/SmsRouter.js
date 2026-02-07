import { Router } from "express";
import { sendSms, getBalance } from "../Controller/SmsController.js";
import { authMiddleware } from "../middleware/authMiddleware.js";

const router = Router();

router.post("/sms", authMiddleware, sendSms);
router.get("/balance", authMiddleware, getBalance);

export default router;
