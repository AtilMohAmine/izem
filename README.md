<p align="center">
   <img src="https://github.com/user-attachments/assets/b6de3739-baf3-4b27-a30a-26eb0def4169" style="width: 215px">
</p>
<h1 align="center">Izem</h1>

**Izem** is a **blazing fast** JavaScript and TypeScript runtime built with Nim 2 and JavaScriptCore. It is designed for exceptional performance and efficiency, capable of handling up to **100,000 requests per second**.

<p align="center">
   <img src="https://github.com/user-attachments/assets/202f3368-b516-4eaa-b00a-d80f6f35bc2b" style="width: 500px">
</p>

## Getting Started

### Installation:

Clone the repository and build the runtime using:

```bash
git clone https://github.com/atilmohamine/izem.git
cd izem
make
```

### Usage:

Once built, you can run JavaScript files using:

```bash
./izem yourfile.js
```

## Starting a Server

You can start a simple server using the `izem.serve` method. Below is an example of how to initialize the server:

```js
izem.serve(4006, (req) => {
    return "Welcome to the Izem Server";
});
```
