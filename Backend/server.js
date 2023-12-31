import express, { response } from "express";
import ytdl from "ytdl-core";
import requestIp from "request-ip";
import logger from "node-color-log";
import dotenv from "dotenv";
import axios from "axios";

dotenv.config();

const app = express();
const port = 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const getClientInfo = async (req) => {
  var clientIp = requestIp.getClientIp(req);
  const API_URL = `http://ipinfo.io/${clientIp}?token=${process.env.IPINFO_TOKEN}`;

  try {
    await axios.get(API_URL).then((res) => {
      console.log(`Request from IP: ${clientIp} | City: ${res.data.city}`);
    });
  } catch (e) {
    console.log(e);
  }
};

app.get("/download", async (req, res) => {
  getClientInfo(req);

  const videoUrl = req.query.url;

  if (!videoUrl) return res.status(400).send("No URL Provided");

  try {
    ytdl
      .getInfo(videoUrl, (err, info) => {
        if (err) {
          console.log(err);
          return res.status(400).send("Error:", err);
        }
      })
      .then(async (info) => {
        const formats = {};
        const formatsList = [];

        const thumbnailUrl = `https://img.youtube.com/vi/${info.player_response.videoDetails.videoId}/mqdefault.jpg`;

        await Promise.all(
          info.formats.map(async (format) => {
            const {
              qualityLabel,
              bitrate,
              url,
              contentLength,
              container,
              hasAudio,
            } = format;

            if (qualityLabel != null && hasAudio) {
              if (
                !formats[qualityLabel] ||
                bitrate > formats[qualityLabel].bitrate
              ) {
                formats[qualityLabel] = url;

                const size = await getContentLength(url);

                const value = {
                  qualityLabel: qualityLabel.slice(0, -1),
                  url: url,
                  size: contentLength
                    ? (contentLength / (1024 * 1024)).toFixed(2) + " MB"
                    : size,
                  extension: container,
                  hasAudio: hasAudio,
                };

                formatsList.push(value);
              }
            }
          })
        );
        if (formats == []) return res.status(400).send("No Formats Found");

        console.log(`${info.videoDetails.title}: ${videoUrl}`);

        res.status(200).json({
          title: info.videoDetails.title,
          formats: formatsList,
          thumbnailUrl: thumbnailUrl,
        });
      })
      .catch((err) => {
        if (err.message == "Not a YouTube domain") {
          console.log("Not a YouTube domain");
          return res.status(400).send("Invalid Domain");
        } else if (
          err.message.toString().includes("does not match expected format")
        ) {
          console.log("does not match expected format");
          return res.status(400).send("Invalid ID");
        } else {
          console.log("Untracked Error: " + err.message);
          res.status(400).send(err.message);
        }
      });
  } catch (err) {
    return res.status(400).send("Error:", err);
  }
});

const getContentLength = async (url) => {
  try {
    const response = await axios.head(url);
    const size =
      (response.headers["content-length"] / (1024 * 1024)).toFixed(2) + " MB";
    return size;
  } catch (e) {
    console.log(e);
    return "- MB";
  }
};

app.get("/ping", (req, res) => {
  return res.status(200).send("I'm Alive dude!");
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
