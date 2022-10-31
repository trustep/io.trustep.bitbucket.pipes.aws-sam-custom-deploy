let resp = {
  error: false,
  code: 200,
  msg: "",
};

export async function handler(event) {
  var helloWorldMsg = process.env.HELLO_WORLD_MSG;
  console.log(helloWorldMsg);
  resp['msg'] = helloWorldMsg;
  return respuesta;
}
