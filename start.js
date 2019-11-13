const spawn = require('child_process').spawn;
const path = require("path");

const exec = (cmd, args=[]) => new Promise((resolve, reject) => {
    console.log(`Started: ${cmd} ${args.join(" ")}`)
    const app = spawn(cmd, args, { stdio: 'inherit' });
    app.on('close', resolve);
    app.on('error', reject);
});

const main = async () => {
    await exec('bash', [path.join(__dirname, './start.sh')]);
};

main().catch(err => {
    console.error(err);
    console.error(err.stack);
    process.exit(-1);
})