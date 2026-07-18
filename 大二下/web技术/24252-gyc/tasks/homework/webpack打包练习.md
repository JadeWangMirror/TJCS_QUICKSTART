# Webpack 基础实验：打包JS、CSS和图片资源

下面是一个完整的Webpack基础实验步骤，从项目建立到最终打包执行。

## 1. 项目初始化

首先创建项目目录并初始化：

```bash
mkdir webpack-demo
cd webpack-demo
npm init -y
```

## 2. 安装Webpack及相关依赖

安装Webpack核心和命令行工具：

```bash
npm install --save-dev webpack webpack-cli
```

安装处理CSS、图片等资源所需的loader：

```bash
npm install --save-dev style-loader css-loader file-loader
```

## 3. 创建项目目录结构

创建以下目录和文件：

```
webpack-demo/
├── dist/
│   └── index.html
├── src/
│   ├── images/
│   │   └── webpack-logo.png
│   ├── styles/
│   │   └── main.css
│   ├── index.js
│   └── utils.js
├── package.json
└── webpack.config.js
```

## 4. 编写源代码文件

### 4.1 创建HTML文件 (`dist/index.html`)

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Webpack Demo</title>
</head>
<body>
    <div id="app"></div>
    <script src="bundle.js"></script>
</body>
</html>
```

### 4.2 创建JavaScript文件 (`src/utils.js`)

```javascript
export function createImageElement(src, alt) {
    const img = document.createElement('img');
    img.src = src;
    img.alt = alt;
    img.width = 200;
    return img;
}
```

### 4.3 创建主JavaScript文件 (`src/index.js`)

```javascript
import { createImageElement } from './utils';
import './styles/main.css';
import logo from './images/webpack-logo.png';

const app = document.getElementById('app');

// 创建标题
const title = document.createElement('h1');
title.textContent = 'Webpack 基础实验';
title.classList.add('title');
app.appendChild(title);

// 创建图片
const img = createImageElement(logo, 'Webpack Logo');
app.appendChild(img);

// 创建按钮
const button = document.createElement('button');
button.textContent = '点击我';
button.classList.add('btn');
app.appendChild(button);

button.addEventListener('click', () => {
    alert('Webpack 打包成功!');
});
```

### 4.4 创建CSS文件 (`src/styles/main.css`)

```css
body {
    font-family: Arial, sans-serif;
    padding: 20px;
    text-align: center;
}

.title {
    color: #2b3a42;
}

.btn {
    background-color: #4CAF50;
    border: none;
    color: white;
    padding: 10px 20px;
    text-align: center;
    text-decoration: none;
    display: inline-block;
    font-size: 16px;
    margin: 20px 2px;
    cursor: pointer;
    border-radius: 4px;
}

.btn:hover {
    background-color: #45a049;
}
```

## 5. 配置Webpack (`webpack.config.js`)

```javascript
const path = require('path');

module.exports = {
    entry: './src/index.js',
    output: {
        filename: 'bundle.js',
        path: path.resolve(__dirname, 'dist')
    },
    module: {
        rules: [
            {
                test: /\.css$/,
                use: ['style-loader', 'css-loader']
            },
            {
                test: /\.(png|svg|jpg|gif)$/,
                use: ['file-loader']
            }
        ]
    }
};
```

## 6. 配置package.json脚本

修改`package.json`中的`scripts`部分：

```json
"scripts": {
    "build": "webpack --mode production",
    "dev": "webpack --mode development --watch"
}
```

## 7. 执行打包

运行生产环境打包：

```bash
npm run build
```

或者开发环境打包并监听文件变化：

```bash
npm run dev
```

## 8. 查看结果

打包完成后，打开`dist/index.html`文件，你应该看到：

- 一个标题"Webpack 基础实验"
- Webpack的logo图片
- 一个绿色按钮，点击会弹出提示框
- 所有样式都已正确应用

## 9. 项目结构说明

- `src/`: 源代码目录
  - `images/`: 存放图片资源
  - `styles/`: 存放CSS样式
  - `index.js`: 应用入口文件
  - `utils.js`: 工具函数
- `dist/`: 打包输出目录
  - `index.html`: HTML模板
  - `bundle.js`: 打包后的JS文件
  - `图片文件`: 经过处理的图片资源
- `webpack.config.js`: Webpack配置文件

## 10. 实验扩展

你可以尝试以下扩展：

1. 添加SASS/LESS支持
2. 使用HTML Webpack Plugin自动生成HTML文件
3. 添加Babel支持转换ES6+语法
4. 配置开发服务器(webpack-dev-server)

这个实验涵盖了Webpack的基础配置，包括JS模块化、CSS处理和图片资源处理，是学习Webpack的良好起点。
