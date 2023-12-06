const express = require('express');
const multer = require('multer');
const app = express();
const port = 3000;

// Configure multer
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, '../Frontend/uploads'); // 保存路径
    },
    filename: function (req, file, cb) {
        cb(null, file.fieldname + '-' + Date.now() + '.' + file.originalname.split('.').pop());
    }
});

const upload = multer({ storage: storage });

// Enable CORS for local testing
app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    next();
});

app.post('/upload', upload.single('image'), (req, res) => {
    res.json({ message: 'File uploaded successfully.', filePath: req.file.path });
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});

