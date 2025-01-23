<?php

function getHttpType(): string
{
    return ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') 
        || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https')) 
        ? 'https://' : 'http://';
}

// 检查是否有上传内容
$uploadData = file_get_contents('php://input');
if ($uploadData === false || empty($uploadData)) {
    http_response_code(404);
    die("Error 404: No data uploaded or invalid request.");
}

// 限制文件大小为 5MB
if (strlen($uploadData) > 5242880) {
    http_response_code(500);
    die("Error 500: File is too large. Maximum file size is 5MB.");
}

// 验证上传的文件是否为 txt 格式
$fileType = finfo_buffer(finfo_open(FILEINFO_MIME_TYPE), $uploadData);
if ($fileType !== 'text/plain') {
    http_response_code(500);
    die("Error 500: Only plain text files (.txt) are allowed.");
}

// 清理控制字符
$uploadData = str_ireplace("\033[?25h", "", $uploadData);

// 获取当前年份和月份
$year = date('Y');
$month = date('m');

// 构造存储目录
$basePath = __DIR__ . "/";
$directory = $basePath . $year . "/" . $month . "/";

// 创建目录（如果不存在）
if (!is_dir($directory) && !mkdir($directory, 0755, true)) {
    http_response_code(500);
    die("Error 500: Failed to create directory.");
}

// 生成唯一文件名
$fileName = "NL" . time() . "-" . strtoupper(substr(md5($uploadData), 0, 6)) . ".txt";

// 构造文件 URL
$baseUrl = rtrim(getHttpType() . $_SERVER['HTTP_HOST'] . dirname($_SERVER['SCRIPT_NAME']), '/'); // 去掉末尾多余的斜杠
$filePath = $directory . $fileName;

// 保存文件
if (file_put_contents($filePath, $uploadData) === false) {
    http_response_code(500);
    die("Error 500: Failed to save the file.");
}

// 返回文件 URL
echo $baseUrl . "/$year/$month/" . $fileName;
