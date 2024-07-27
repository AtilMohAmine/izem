a = 5
a = a * 2
console.log("Hello World "+a)

myruntime.server(4007, function(req) {
    return "Hello from js "+req.method;
  });