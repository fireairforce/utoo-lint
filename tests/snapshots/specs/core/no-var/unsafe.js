function escaped(ready) {
  if (ready) {
    var value = 1;
  }
  return value;
}

function redeclared() {
  var item = 1;
  var item = 2;
  return item;
}

function closures() {
  const callbacks = [];
  for (var index = 0; index < 2; index++) {
    callbacks.push(() => index);
  }
  return callbacks;
}

function tdz() {
  var result = result;
  return result;
}
