'use strict';
const spawn = require('child_process').spawn;
const path = require('path');
const http = require('http');
const https = require('https');

const get = (url, options = {}) => new Promise((resolve, reject) => ((new URL(url).protocol === 'http:') ? http : https)
    .get(url, options, (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
            const body = Buffer.concat(chunks).toString('utf-8');
            if (res.statusCode < 200 || res.statusCode > 300) {
                return reject(Object.assign(
                    new Error(`Invalid status code '${res.statusCode}' for url '${url}'`),
                    { res, body }
                ));
            }
            return resolve(body)
        });
    })
    .on('error', reject)
)

const exec = (cmd, args = [], options = {}) => new Promise((resolve, reject) =>
    spawn(cmd, args, { stdio: 'inherit', ...options })
        .on('close', code => {
            if (code !== 0) {
                return reject(Object.assign(
                    new Error(`Invalid exit code: ${code}`),
                    { code }
                ));
            };
            return resolve(code);
        })
        .on('error', reject)
);

const trimLeft = (value, charlist = '/') => value.replace(new RegExp(`^[${charlist}]*`), '');
const trimRight = (value, charlist = '/') => value.replace(new RegExp(`[${charlist}]*$`), '');
const trim = (value, charlist) => trimLeft(trimRight(value, charlist));

const main = async () => {
    let branch = process.env.INPUT_BRANCH;
    const repository = trim(process.env.INPUT_REPOSITORY || process.env.GITHUB_REPOSITORY);
    const github_url_protocol = trim(process.env.INPUT_GITHUB_URL).split('//')[0];
    const github_url = trim(process.env.INPUT_GITHUB_URL).split('//')[1];
    if (!branch) {
        const headers = {
            'User-Agent': 'github.com/ad-m/github-push-action'
        };
        if (process.env.INPUT_GITHUB_TOKEN) headers.Authorization = `token ${process.env.INPUT_GITHUB_TOKEN}`;
        const body = JSON.parse(await get(`${process.env.GITHUB_API_URL}/repos/${repository}`, { headers }))
        branch = body.default_branch;
    }
    await exec('bash', [path.join(__dirname, './start.sh')], {
        env: {
            ...process.env,
            INPUT_BRANCH: branch,
            INPUT_REPOSITORY: repository,
            INPUT_GITHUB_URL_PROTOCOL: github_url_protocol,
            INPUT_GITHUB_URL: github_url,
        }
    });
};

main().catch(err => {
    console.error(err);
    process.exit(-1);
})
