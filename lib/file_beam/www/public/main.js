window.app = 
  {
    show: function (title) {
      console.log(title);
    }
  };

window.stream_sse_for_build = function(buid) {
    var source = new EventSource("/stats_sse/" + buid)
    source.onmessage = function(event) {
      console.log(event);
    }
  };
