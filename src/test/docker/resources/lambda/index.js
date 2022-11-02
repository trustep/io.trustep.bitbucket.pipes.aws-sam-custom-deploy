let resp = {
  error: false,
  code: 200,
  msg: "",
};

exports.handler = async (event) => {
  var helloWorldMsg = process.env.HELLO_WORLD_MSG;
  console.log(helloWorldMsg);
  resp['msg'] = helloWorldMsg;
  return resp;
}
