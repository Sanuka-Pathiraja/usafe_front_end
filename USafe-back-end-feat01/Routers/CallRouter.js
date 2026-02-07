import { Router } from "express";
import { initiateCall } from "../Controller/CallController.js";
import { authMiddleware } from "../middleware/authMiddleware.js";

const router = Router();

router.post("/call", authMiddleware, initiateCall);

export default router;
