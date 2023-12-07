console.log("Get a random number between 0 and 9.");

let randomInt = Math.floor(Math.random() * 10);
console.log(`The random Int is ${randomInt}`);

return Functions.encodeUint256(randomInt);