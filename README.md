<p align="center">
   <img src="https://github.com/user-attachments/assets/d36b27aa-29a1-466b-9571-1471cabff1fd" style="width: 270px">
</p>
<h1 align="center">Izem</h1>

**Izem** is a **blazing fast** javascript/typescript runtime built with Nim 2 and JavaScriptCore. It is designed for exceptional performance and efficiency, capable of handling up to **100,000 requests per second**.

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
