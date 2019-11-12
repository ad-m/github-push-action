const spawn = require('child_process').spawn;

const main = () => new Promise((resolve, reject) => {
    const ssh = spawn('bash', ['start.sh'], { stdio: 'inherit' });
    ssh.on('close', resolve);
    ssh.on('error', reject);
});

main().catch(err => {
    console.err(err);
    console.err(err.stack);
    process.exit(-1);
})