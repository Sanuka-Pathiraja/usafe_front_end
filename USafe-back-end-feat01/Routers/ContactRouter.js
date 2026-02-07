import express from "express";
import { createContact, getContacts, updateContact, deleteContact } from "../Controller/ContactController.js";
import { authMiddleware } from "../middleware/authMiddleware.js";

const contactRouter = express.Router();
contactRouter.post("/add", authMiddleware, createContact);
contactRouter.get("/", authMiddleware, getContacts);
contactRouter.put("/update/:id", authMiddleware, updateContact);
contactRouter.delete("/delete/:id", authMiddleware, deleteContact);
export default contactRouter;
