window.app = 
  {
    show: function (title) {
      console.log(title);
    }
  };

window.stream_sse_for_build = function(buid, stats_callback) {
    var source = new EventSource("/stats_sse/" + buid)
    source.onmessage = function(event) {
      data = JSON.parse(event.data)
      console.log(data)

      stats_callback(data)
    }
  };

window.transfer_speed_representation = function(bps) {
  if(bps < 1024) {
    return Math.round(bps) + "B/s";
  }

  if(bps < 1024 * 1024) {
    return Math.round(bps / 1024) + "kB/s";
  }

  return Math.round(bps / (1024 * 1024)) + "MB/s"
}

window.update_progress_bar_with_stats = function(stats) {
  if(stats.bytes_transferred > 0) {
    rounded_percent = Math.round(stats.progress * 100)
    current_speed = stats.current_speed

    progres_bar_text = 
    $("#progress-container").show()
    $("#progress-bar").width((stats.progress * 100) + "%")
    $("#progress-bar").text(rounded_percent + "%, " + transfer_speed_representation(stats.current_speed))
  }
}


window.nop = function(whatever) {}
