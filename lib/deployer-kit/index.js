const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function main() {
  // Replace occurrences in the specified file with the provided arguments
  const filePath = "lib/deployer-kit/template";
  const args = process.argv.slice(3);

  let replacementPathToExample = process.argv[2];

  if (
    replacementPathToExample === undefined ||
    replacementPathToExample === "-h" ||
    replacementPathToExample === "--help"
  ) {
    printHelp();
    process.exit(0);
  } else if (replacementPathToExample === "-v" || replacementPathToExample === "--version") {
    console.log(JSON.parse(fs.readFileSync("lib/deployer-kit/package.json", "utf8")).version);
    process.exit(0);
  }

  let newFilePath;
  let contractName;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "-o":
      case "--output":
        // Check if there's another argument after --output and the argument is not another command
        if (i + 1 < args.length && args[i + 1].charAt(0) !== "-") {
          newFilePath = args[i + 1];
          i++; // Skip the next argument
          break;
        } else {
          console.error("Error: --output flag requires the path to a directory");
          process.exit(1);
        }
      case "-n":
      case "--name":
        // Check if there's another argument after --name and the argument is not another command
        if (i + 1 < args.length && args[i + 1].charAt(0) !== "-") {
          contractName = args[i + 1];
          i++; // Skip the next argument
          break;
        } else {
          console.error("Error: --name flag requires the name of the contract");
          process.exit(1);
        }
      default:
        printHelp();
        process.exit(1);
    }
  }

  // Extract the file name from the path by splitting the string based on the '/' delimiter
  const parts = replacementPathToExample.split("/");
  // Get the last part of the path, which is the file name with the extension
  const fileNameWithExtension = parts[parts.length - 1];
  // Split the file name by the dot('.') to get the name and the extension separately
  const fileNameParts = fileNameWithExtension.split(".");
  // Check if there is more than one element in the fileNameParts array
  let replacementExample;
  if (fileNameParts.length > 1) {
    // Join the parts of the file name excluding the last element (the extension)
    replacementExample = fileNameParts.slice(0, -1).join(".");
  } else {
    // The file name as it is if no extension is found
    replacementExample = fileNameParts[0];
  }

  // if contract name was not provided, use contract file name instead
  contractName = contractName ?? replacementExample;

  let filePathPrefix = newFilePath ?? "script/deployers";

  // create the directory if it doesn't exist
  if (!fs.existsSync(filePathPrefix)) {
    fs.mkdirSync(filePathPrefix, { recursive: true });
  }

  const formattedPath = path.join(filePathPrefix, contractName + "Deployer.s.sol");

  replaceInFile(filePath, formattedPath, replacementExample, replacementPathToExample, contractName);
}

const replaceInFile = (filePath, newFilePath, replacementExample, replacementPathToExample, contractName) => {
  execSync("forge build --skip s.sol --skip t.sol");

  // get abi
  const contractFileName = path.join("out", replacementExample + ".sol", contractName + ".json");
  let fileContents;
  try {
    fileContents = fs.readFileSync(contractFileName, "utf8");
  } catch {
    console.error("Contract not found. Did you provide the correct contract name?");
    process.exit(1);
  }
  abi = JSON.parse(fileContents).abi;

  // get constructor and initializer args, format them, if none present, set to empty array, if initArgs is undefined, it means no initializer function is present
  let constructorArgs = abi.find((element) => element.type == "constructor");
  let initArgs = abi.find((element) => element.type == "function" && element.name == "initialize");

  if (initArgs !== undefined && constructorArgs !== undefined) {
    constructorArgs.inputs = constructorArgs.inputs.map((e) => {
      const duplicate = initArgs.inputs.find((i) => i.name == e.name);
      return duplicate !== undefined ? { ...e, name: "c_" + e.name } : e;
    });
  }

  constructorArgs = constructorArgs?.inputs.map((element) => formatInput(element.internalType, element.name)) ?? [];
  initArgs = initArgs?.inputs.map((element) => formatInput(element.internalType, element.name));

  fs.readFile(filePath, "utf8", (err, data) => {
    if (err) {
      return console.error(err);
    }

    let regexExample = new RegExp("<Example>", "g");
    let regexExampleVar = new RegExp("<example>", "g");
    let regexArgsConstruct = new RegExp("<, uint256 constructArg>", "g");
    let regexArgsConstructNames = new RegExp("<constructArg>", "g");
    let regexArgs = new RegExp("<, uint256 initArg>", "g");
    let regexArgsNames = new RegExp("<initArg>", "g");
    let regexPathToExample = new RegExp("<src/Example.sol>", "g");
    let regexInitData = new RegExp("<initData>", "g");

    let initData = "abi.encodeCall(<Example>.initialize, (<initArg>))";
    let updatedData = initData.replace(regexExample, contractName);
    if (initArgs === undefined) {
      updatedData = `"";\n        revert("${replacementExample} is not initializable")`;
    } else {
      updatedData = updatedData.replace(
        regexArgsNames,
        initArgs.length === 0 ? "" : initArgs.map((e) => e.name).join(", "),
      );
    }

    // replace all non character or number characters with an empty string
    replacementExample = replacementExample.replace(/[^a-zA-Z0-9]/g, "");

    updatedData = data.replace(regexInitData, updatedData);
    updatedData = updatedData.replace(regexExample, contractName);
    updatedData = updatedData.replace(
      regexExampleVar,
      replacementExample.charAt(0).toLowerCase() + replacementExample.slice(1),
    );
    updatedData = updatedData.replace(
      regexArgsConstruct,
      constructorArgs.length === 0 ? "" : ", " + constructorArgs.map((e) => e.definition).join(", "),
    );
    updatedData = updatedData.replace(regexArgsConstructNames, constructorArgs.map((e) => e.name).join(", "));
    updatedData = updatedData.replace(
      regexArgs,
      initArgs === undefined || initArgs.length === 0 ? "" : ", " + initArgs.map((e) => e.definition).join(", "),
    );
    updatedData = updatedData.replace(regexPathToExample, replacementPathToExample);

    fs.writeFile(newFilePath, updatedData, "utf8", (err) => {
      if (err) {
        console.error(err);
      } else {
        execSync("forge fmt");
        console.log(`generated ${newFilePath}`);
      }
    });
  });
};

const formatInput = (type, name) => {
  // order of operations is important, as some types are caught by multiple cases
  // if the first 6 characters of the type are "string", add memory to the type
  if (type.slice(0, 6) == "string") type += " memory";
  // if the first 5 characters of the type are "bytes", add memory to the type
  else if (type.slice(0, 5) == "bytes") type += " memory";
  // if the first 8 characters of the type are "contract", remove the "contract " from the type
  else if (type.slice(0, 8) == "contract") type = type.slice(9);
  // if the first 6 characters of the type are "struct" and it ends in [] or [(number)], remove the "struct " from the type and add memory
  else if (/^struct.*\[\d*\]$/.test(type)) type = type.slice(7) + " memory";
  // if the first 4 characters of the type are "enum" and it ends in [] or [(number)], remove the "enum " from the type and add memory
  else if (/^enum.*\[\d*\]$/.test(type)) type = type.slice(5) + " memory";
  // if the type is an array, add memory to the type
  else if (/\[\d*\]$/.test(type)) type += " memory";
  // if the first 4 characters of the type are "enum", remove the "enum " from the type
  else if (type.slice(0, 4) == "enum") type = type.slice(5);
  // if the first 6 characters of the type are "struct", remove the "struct " from the type and add memory
  else if (type.slice(0, 6) == "struct") type = type.slice(7) + " memory";

  return { definition: `${type} ${name}`, name };
};

const printHelp = () => {
  console.log(
    "\nUsage: node lib/deployer-kit <pathToContract> [-o output] [-n name]\n\nCommands:\n  -o, --output\t\tOutput directory (default: script/deployers)\n  -n, --name\t\tName of the contract in case it differs from the file name (default: name of the contract file)\n\nOptions:\n  -h, --help\t\tPrint help\n  -v, --version\t\tPrint version\n\nDocumentation can be found at https://github.com/0xPolygon/deployer-kit",
  );
};

main();
