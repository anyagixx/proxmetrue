require('dotenv').config();
const express = require("express");
const { spawn, exec } = require("child_process");
const app = express();
app.use(express.json());
const commandToRun = "cd ~ && bash serv00keep.sh";
function runCustomCommand() {
    exec(commandToRun, (err, stdout, stderr) => {
        if (err) console.error("Command execution failed", err);
        else console.log("Command executed successfully", stdout);
    });
}
app.get("/up", (req, res) => {
    runCustomCommand();
    res.type("html").send("<pre>Serv00 keepalive triggered successfully.</pre>");
});
app.get("/re", (req, res) => {
    const additionalCommands = `
        USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
        FULL_PATH="/home/\${USERNAME}/domains/\${USERNAME}.serv00.net/logs"
        cd "\$FULL_PATH"
        pkill -f 'run -c con' || echo "No process to terminate, ready to execute restart..."
        sbb="\$(cat sb.txt 2>/dev/null)"
        nohup ./"\$sbb" run -c config.json >/dev/null 2>&1 &
        sleep 2
        (cd ~ && bash serv00keep.sh >/dev/null 2>&1) &  
        echo 'The main process restarted successfully. Please check whether the three primary nodes are available. If not, try the restart page again or reset the ports.'
    `;
    exec(additionalCommands, (err, stdout, stderr) => {
        console.log('stdout:', stdout);
        console.error('stderr:', stderr);
        if (err) {
            return res.status(500).send(`Error: ${stderr || stdout}`);
        }
        res.type('text').send(stdout);
    });
}); 

const changeportCommands = "cd ~ && bash webport.sh"; 
function runportCommand() {
exec(changeportCommands, { maxBuffer: 1024 * 1024 * 10 }, (err, stdout, stderr) => {
        console.log('stdout:', stdout);
        console.error('stderr:', stderr);
        if (err) {
            console.error('Execution error:', err);
            return res.status(500).send(`Error: ${stderr || stdout}`);
        }
        if (stderr) {
            console.error('stderr output:', stderr);
            return res.status(500).send(`stderr: ${stderr}`);
        }
        res.type('text').send(stdout);
    });
}
app.get("/rp", (req, res) => {
   runportCommand();  
   res.type("html").send("<pre>The three node ports have been reset. Close this page, wait 20 seconds, then open /list/your-uuid to view the updated node and subscription information.</pre>");
});
app.get("/list/key", (req, res) => {
    const listCommands = `
        USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
        USERNAME1=$(whoami)
        FULL_PATH="/home/\${USERNAME1}/domains/\${USERNAME}.serv00.net/logs/list.txt"
        cat "\$FULL_PATH"
    `;
    exec(listCommands, (err, stdout, stderr) => {
        if (err) {
            console.error(`Path verification failed: ${stderr}`);
            return res.status(404).send(stderr);
        }
        res.type('text').send(stdout);
    });
});

app.get("/jc", (req, res) => {
    const ps = spawn("ps", ["aux"]);
    res.type("text");
    ps.stdout.on("data", (data) => res.write(data));
    ps.stderr.on("data", (data) => res.write(`Error: ${data}`));
    ps.on("close", (code) => {
        if (code !== 0) {
            res.status(500).send(`ps aux exited, error code: ${code}`);
        } else {
            res.end();
        }
    });
});

app.use((req, res) => {
    res.status(404).send('Available paths: /up for keepalive, /re to restart, /rp to reset node ports, /jc to view current system processes, and /list/your-uuid to view node and subscription information.');
});
setInterval(runCustomCommand, (2 * 60 + 15) * 60 * 1000);
app.listen(3000, () => {
    console.log("Server is running on port 3000");
    runCustomCommand();
});
