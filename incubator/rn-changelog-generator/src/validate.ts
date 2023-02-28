import validate from "./utils/validateChangelog";

function handler(argv: { commitMsg: string }) {
  return validate(argv.commitMsg);
}

export default {
  handler,
  args: {
    commitMsg: {
      alias: "c",
      string: true,
      describe:
        "Validate if commit message follows changelog format. Returns 'missing', 'invalid', or 'valid'.",
      demandOption: true,
    },
  },
};
