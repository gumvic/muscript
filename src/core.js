const immutable = require("immutable");
const { namify } = require("./utils");

const parse = require("./parse");
const check = require("./check");
const generate = require("./generate");

function castType(to, from) {
  return to.castFrom(from) || from.castTo(to);
}

function readableType({ readable }) {
  return readable;
}

function matchType({ type: aType, value: aValue }, { type: bType, value: bValue }) {
  if (
    aType === bType &&
    aValue !== undefined && bValue !== undefined &&
    aValue === bValue) {
    return 1;
  }
  else if (
    aType !== bType ||
    aValue !== bValue) {
    return -1;
  }
  else {
    return 0;
  }
}

const tAny = {
  type: "any",
  castFrom(_) {
    return true;
  },
  castTo({ type: toType }) {
    return toType === "any";
  },
  readable: "*"
};

function tPrimitive(type, value) {
  return {
    type,
    value,
    castFrom({ type: fromType, value: fromValue }) {
      return (
        (type === fromType) &&
        (value === undefined || value === fromValue));
    },
    castTo({ type: toType, value: toValue }) {
      return (
        (type === toType) &&
        (value === undefined || value === toValue));
    },
    readable: value === undefined ? type : `${type}(${value})`
  };
}

function tFromValue(value) {
  if (value === undefined) {
    return tPrimitive("undefined");
  }
  else if (value === null) {
    return tPrimitive("null");
  }
  else {
    return tPrimitive(typeof value, value);
  }
}

function checkFunctionArgs(args, _args) {
  if (_args.length !== args.length) {
    return false;
  }
  else {
    for (let i = 0; i < _args.length; i++) {
      if (!castType(args[i], _args[i])) {
        return false;
      }
    }
    return true;
  }
}

function staticFunction(args, res) {
  const readableArgs = args.map(readableType);
  const readableRes = readableType(res);
  return {
    type: "function",
    fn(..._args) {
      return checkFunctionArgs(args, _args) && res;
    },
    castFrom({ type: fromType, fn: fromFn }) {
      if (fromType === "function") {
        const toRes = res;
        const fromRes = fromFn(...args);
        return fromRes && castType(toRes, fromRes);
      }
      else {
        return false;
      }
    },
    castTo(to) {
      // TODO
      return false;
    },
    readable: `fn(${readableArgs.join(", ")}) -> ${readableRes}`
  };
}

function dynamicFunction(args, resFn) {
  const readableArgs = args.map(readableType);
  const readableRes = "?";
  return {
    type: "function",
    fn(..._args) {
      return checkFunctionArgs(args, _args) && resFn(..._args);
    },
    castFrom({ type: fromType, fn: fromFn }) {
      if (fromType === "function") {
        const toRes = resFn(...args);
        const fromRes = fromFn(...args);
        return toRes && fromRes && castType(res, fromRes);
      }
      else {
        return false;
      }
    },
    castTo(to) {
      // TODO
      return false;
    },
    readable: `fn(${readableArgs.join(", ")}) -> ${readableRes}`
  };
}

function tFunction(...args) {
  const res = args.pop();
  if (typeof res === "function") {
    return dynamicFunction(args, res);
  }
  else {
    return staticFunction(args, res);
  }
};

function tMultiFunction(...functions) {
  const readableFunctions = functions.map(readableType);
  return {
    type: "function",
    fn(...args) {
      for(let { fn } of functions) {
        const res = fn(...args);
        if (res) {
          return res;
        }
      }
      return false;
    },
    castFrom(from) {
      for(let to of functions) {
        if(!cast(to, from)) {
          return false;
        }
      }
      return false;
    },
    castTo(to) {
      // TODO
      return false;
    },
    readable: `fns(${readableFunctions.join(", ")})`
  };
}

/*function tOr(...types) {
  const readableTypes = types.map(readableType);
  return {
    type: "or",
    types,
    castFrom(from) {
      for(let to of types) {
        if (castType(to, from)) {
          return true;
        }
      }
      return false;
    },
    castTo(to) {
      for(let from of types) {
        if (!castType(to, from)) {
          return false;
        }
      }
      return true;
    },
    readable: `(${readableTypes.join(" | ")})`
  };
}

function tAnd(...types) {
  const readableTypes = types.map(readableType);
  return {
    type: "and",
    types,
    castFrom(from) {
      for(let to of types) {
        if (!castType(to, from)) {
          return false;
        }
      }
      return true;
    },
    castTo(to) {
      for(let from of types) {
        if (castType(to, from)) {
          return true;
        }
      }
      return false;
    },
    readable: `(${readableTypes.join(" & ")})`
  };
}*/

function tNot(type) {
  return {
    type: "not",
    castFrom(from) {
      return !cast(type, from);
    },
    castTo(to) {
      return !cast(to, type);
    },
    readable: `!${readableType(type)}`
  };
}

function define(name, value, meta) {
  global.monada$meta[name] = meta || {};
  global[namify(name)] = value;
  return value;
}

function getMeta(name) {
  return global.monada$meta[name];
}

function compile(src) {
  const parsed = parse(src);
  const checked = check(parsed);
  const generated = generate(checked);
  return eval(generated);
}

function init() {
  global.monada$meta = {};

  define("define", define);
  define("getMeta", getMeta);
  define("compile", compile);

  define("immutable", immutable);

  define("castType", castType);
  define("readableType", readableType);

  define("tAny", tAny);
  define("tUndefined", tPrimitive("undefined"));
  define("tNull", tPrimitive("null"));
  define("tBoolean", tPrimitive("boolean"));
  define("tNumber", tPrimitive("number"));
  define("tString", tPrimitive("string"));
  define("tPrimitive", tPrimitive);
  define("tFromValue", tFromValue);
  define("tFunction", tFunction);
  define("tMultiFunction", tMultiFunction);
  define("tNot", tNot);

  define("==", immutable.is, {
    type: tFunction(tAny, tAny, (a, b) => {
      const match = matchType(a, b);
      if (match === 1) {
        return tFromValue(true);
      }
      else if (match === -1) {
        return tFromValue(false);
      }
      else {
        return tBoolean;
      }
    })
  });
  define("+", (a, b) => a + b, {
    type: tMultiFunction(
      tFunction(tNumber, tNumber, ({ value: a }, { value: b }) =>
        a !== undefined && b != undefined ? tFromValue(a + b) : tNumber),
      tFunction(tString, tString, ({ value: a }, { value: b }) =>
        a !== undefined && b != undefined ? tFromValue(a + b) : tString))
  });
  define("print", (x) => console.log(x), {
    type: tFunction(tAny, tUndefined)
  });
}

module.exports = init;