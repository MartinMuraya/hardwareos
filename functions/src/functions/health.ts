import { onRequest } from "firebase-functions/v2/https";
import { PUBLIC_FN_OPTS } from "../config/functionOptions";

export const healthCheck = onRequest(PUBLIC_FN_OPTS, (request, response) => {
  response.status(200).json({
    status: "ok",
    timestamp: new Date().toISOString(),
    service: "hardwareos-api"
  });
});
