import express from "express";
import ytdl from "ytdl-core";

const app = express();
const port = 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/download", (req, res) => {
  const videoUrl = req.query.url;

  if (!videoUrl) res.status(400).send("No URL Provided");

  console.log(videoUrl);

  try {
    ytdl
      .getInfo(videoUrl, (err, info) => {
        if (err) {
          res.status(400).send("Error:", err);
        }
      })
      .then((info) => {
        const formats = {};
        const formatsList = [];

        const thumbnailUrl = `https://img.youtube.com/vi/${info.player_response.videoDetails.videoId}/mqdefault.jpg`;

        info.formats.forEach((format) => {
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

              const value = {
                qualityLabel: qualityLabel.slice(0, -1),
                url: url,
                size: contentLength
                  ? (contentLength / (1024 * 1024)).toFixed(2) + " MB"
                  : "- MB",
                extension: container,
                hasAudio: hasAudio,
              };

              formatsList.push(value);
            }
          }
        });

        if (formats == []) res.status(400).send("No Formats Found");

        // console.log(formatsList);

        res.status(200).json({
          title: info.videoDetails.title,
          formats: formatsList,
          thumbnailUrl: thumbnailUrl,
        });
      })
      .catch((err) => {
        if (err.message == "Not a YouTube domain") {
          res.status(400).send("Invalid Domain");
        } else if (
          err.message.toString().includes("does not match expected format")
        ) {
          console.log(err.message);
          res.status(400).send("Invalid ID");
        } else res.status(400).send(err.message);
      });
  } catch (err) {
    res.status(400).send("Error:", err);
  }
});

// app.post("/download", (req, res) => {
//   res.status(200).send("download Working");
// });

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
