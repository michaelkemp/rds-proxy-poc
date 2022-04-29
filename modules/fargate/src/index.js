'use strict';
const PORT = 8080;

const MYENV = process.env.MYENV;

const express = require("express");
const app = express();

const server = app.listen(PORT, () => { console.log("Listening on port:", PORT); });

app.get("/", (req, res) => { res.send("Environment Variable: " + MYENV + "<br>" + Math.random()); });
app.get("/health", (req, res) => { res.sendStatus(200); });


