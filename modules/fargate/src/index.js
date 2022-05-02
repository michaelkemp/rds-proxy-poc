'use strict';
const PORT = 8080;

const DBHOST = process.env.DBHOST;
const DBNAME = process.env.DBNAME;
const DBUSER = process.env.DBUSER;
const DBPASS = process.env.DBPASS;

const express = require("express");
const app = express();

const server = app.listen(PORT, () => { console.log("Listening on port:", PORT); });
//app.get("/", (req, res) => { res.send("Random: " + Math.random()); });
app.get("/health", (req, res) => { res.sendStatus(200); });

const Pool = require('pg').Pool;

const pool = new Pool({
  host: DBHOST,
  database: DBNAME,
  user: DBUSER,
  password: DBPASS,
  port: 5432,
})

pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err)
  process.exit(-1)
})

async function registerPerson(person) {
  const text = `
    INSERT INTO people (fullname, gender, phone, age)
    VALUES ($1, $2, $3, $4)
    RETURNING id
  `;
  const values = [person.fullname, person.gender, person.phone, person.age];
  pool.query(text, values, (err, res) => {
    if (err) {
      console.log("Postgres Insert Error: ", err);
    }
    if (res) {
      return res;
    }
  });
}

async function getPerson(personId) {
  const text = `SELECT * FROM people WHERE id = $1`;
  const values = [personId];
  pool.query(text, values, (err, res) => {
    if (err) {
      console.log("Postgres Insert Error: ", err);
    }
    if (res) {
      return res;
    }
  });
}

async function updatePersonName(personId, fullname) {
  const text = `UPDATE people SET fullname = $2 WHERE id = $1`;
  const values = [personId, fullname];
  pool.query(text, values, (err, res) => {
    if (err) {
      console.log("Postgres Insert Error: ", err);
    }
    if (res) {
      return res;
    }
  });
}

async function removePerson(personId) {
  const text = `DELETE FROM people WHERE id = $1`;
  const values = [personId];
  pool.query(text, values, (err, res) => {
    if (err) {
      console.log("Postgres Insert Error: ", err);
    }
    if (res) {
      return res;
    }
  });
}

(async () => {
  let crap = "";
  let latestPID;

  for(let i=0; i<10; ++i) {
    let person = {
      fullname: Math.random().toString(36).replace(/[^a-z]+/g, '').substring(0, 5) + " " + Math.random().toString(36).replace(/[^a-z]+/g, '').substring(0, 8),
      gender:   "F",
      phone:    Math.floor(Math.random() * (9999999 - 1111111 + 1) + 1111111).toString(),
      age:      Math.floor(Math.random() * (99 - 20 + 1) + 20)
    }
    let registerResult = await registerPerson(person);
    let personId = registerResult.rows[0]["id"];
    latestPID = personId;
    crap += "Registered person id: " + personId +"<br>";
    console.log("Registered a person with id: " + personId);
  }

  // Obtain the full person object from the database.
  const getPersonResult = await getPerson(latestPID);
  crap += "SELECT query for person '" + latestPID + "': " +  JSON.stringify(getPersonResult.rows[0], null, "  ") +"<br>";
  console.log("SELECT query for person '" + latestPID + "': " + JSON.stringify(getPersonResult.rows[0], null, "  "));

  //await updatePersonName(personId, "Jane Johnson");
  //const getChangedPersonResult = await getPerson(personId);
  // Clean up the database by removing the person record.
  //await removePerson(personId);

  app.get("/", (req, res) => { res.send(crap); });

  await pool.end();
})();
