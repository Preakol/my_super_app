const tailwind_config = require("../deps/moon/assets/tailwind.config.js");

tailwind_config.content = [
  "../lib/**/*.ex",
  "../lib/**/*.heex",
  "../lib/**/*.eex",
  "./js/**/*.js",

  "../deps/flashy/**/*.*ex", 
  "../deps/moon/lib/**/*.ex",
  "../deps/moon/lib/**/*.heex",
  "../deps/moon/lib/**/*.eex",
  "../deps/moon/assets/js/**/*.js",
];
module.exports = tailwind_config;