const bcrypt = require("bcryptjs");

const password = process.argv[2] || "admin";
const hash = bcrypt.hashSync(password, 12);
console.log(hash);
