console.log("Get a random number between 0 and 3.");

let randomInt = Math.floor(Math.random() * 4);
console.log(`The random Int is ${randomInt}`);

return Functions.encodeUint256(randomInt);