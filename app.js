a = 5
a = a * 2
console.log("Hello World "+a)
/*
b = setTimeout(function() {
  console.log("hi"+a);
}, 10000)

setTimeout(function() {clearTimeout(b)}, 2000)*/
//clearTimeout(b)

interval = setInterval(function() {
  console.log("interval"+a++);
},1000)

t = setTimeout(function() {
  clearInterval(interval)
  console.log("delete interval")
}, 2000)//=================
/*



/*myruntime.server(4007, function(req) {
    return "Hello from js "+req.method;
  });*/