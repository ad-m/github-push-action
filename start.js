const exec = require("@actions/exec");
const path = require("path");

const main = async () => {
  await exec(path.join(__dirname, "./start.sh"));
};

main().catch(err => {
  console.error(err);
  console.error(err.stack);
  process.exit(err.code || -1);
});
