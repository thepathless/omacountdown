.pragma library

function calculateCountdown(now, targetDateStr, targetTimeStr) {
  if (!targetDateStr || targetDateStr === "") return null;

  var target = new Date(targetDateStr + "T" + (targetTimeStr || "23:59:59"));
  if (isNaN(target.getTime())) return null;

  var diffMs = target.getTime() - now.getTime();
  var isPast = diffMs < 0;
  var absDiffMs = Math.abs(diffMs);

  var totalMinutes = Math.floor(absDiffMs / 60000);
  var totalHours = Math.floor(totalMinutes / 60);
  var totalDays = Math.floor(totalHours / 24);

  var yNow = now.getFullYear();
  var mNow = now.getMonth();
  var dNow = now.getDate();
  var yTarget = target.getFullYear();
  var mTarget = target.getMonth();
  var dTarget = target.getDate();

  var years, months, days;
  if (isPast) {
    years = yNow - yTarget;
    months = mNow - mTarget;
    days = dNow - dTarget;
  } else {
    years = yTarget - yNow;
    months = mTarget - mNow;
    days = dTarget - dNow;
  }

  if (days < 0) {
    months--;
    var prevMonth = new Date(yNow, mNow, 0);
    days += prevMonth.getDate();
  }
  if (months < 0) {
    years--;
    months += 12;
  }

  return {
    years: years, months: months, days: days,
    hours: totalHours % 24, minutes: totalMinutes % 60,
    totalDays: totalDays, totalHours: totalHours, totalMinutes: totalMinutes,
    isPast: isPast
  };
}

function formatBarText(countdown, name, mode) {
  if (!countdown) return name || "No countdown";
  var timeStr = formatCompact(countdown, mode);
  return (name || "") + " " + timeStr;
}

function formatCompact(countdown, mode) {
  if (!countdown) return "";
  switch (mode) {
    case "years": return countdown.years + "y";
    case "months": return countdown.months + "mo";
    case "days": return countdown.totalDays + "d";
    case "hours": return countdown.totalHours + "h";
    case "minutes": return countdown.totalMinutes + "m";
    case "auto": default:
      if (countdown.years > 0) return countdown.years + "y";
      if (countdown.months > 0) return countdown.months + "mo";
      if (countdown.totalDays > 0) return countdown.totalDays + "d";
      if (countdown.totalHours > 0) return countdown.totalHours + "h";
      return countdown.totalMinutes + "m";
  }
}

function formatDetailed(countdown) {
  if (!countdown) return "No target";
  var parts = [];
  if (countdown.years > 0) parts.push(countdown.years + "y");
  if (countdown.months > 0) parts.push(countdown.months + "mo");
  if (countdown.days > 0) parts.push(countdown.days + "d");
  if (countdown.hours > 0) parts.push(countdown.hours + "h");
  if (countdown.minutes > 0) parts.push(countdown.minutes + "m");
  if (parts.length === 0) parts.push("0m");
  return parts.join(" ");
}

function formatRelative(countdown) {
  if (!countdown) return "";
  return formatDetailed(countdown) + (countdown.isPast ? " ago" : " left");
}

function getIcon(iconStyle) {
  switch (iconStyle) {
    case "rocket": return "\uf135";
    case "nerd": return "\uf135";
    case "hourglass": return "\uf252";
    case "none": return "";
    default: return "\uf135";
  }
}

function isUrgent(countdown, thresholdDays) {
  if (!countdown || thresholdDays <= 0) return false;
  return countdown.totalDays <= thresholdDays;
}

function isValidDate(dateStr) {
  if (!dateStr || dateStr === "") return false;
  var match = dateStr.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return false;
  var y = parseInt(match[1], 10);
  var m = parseInt(match[2], 10);
  var d = parseInt(match[3], 10);
  if (m < 1 || m > 12) return false;
  if (d < 1 || d > 31) return false;
  var test = new Date(y, m - 1, d);
  return test.getFullYear() === y && test.getMonth() === m - 1 && test.getDate() === d;
}

function isValidTime(timeStr) {
  if (!timeStr || timeStr === "") return true;
  var match = timeStr.match(/^(\d{2}):(\d{2})$/);
  if (!match) return false;
  var h = parseInt(match[1], 10);
  var m = parseInt(match[2], 10);
  return h >= 0 && h <= 23 && m >= 0 && m <= 59;
}

function nextMode(current) {
  var modes = ["auto", "years", "months", "days", "hours", "minutes"];
  var idx = modes.indexOf(current);
  return modes[(idx + 1) % modes.length];
}

function nextIconStyle(current) {
  var styles = ["rocket", "nerd", "hourglass", "none"];
  var idx = styles.indexOf(current);
  return styles[(idx + 1) % styles.length];
}

function getSelectedCountdown(countdowns, index) {
  if (!countdowns || countdowns.length === 0) return null;
  var i = Math.max(0, Math.min(index || 0, countdowns.length - 1));
  return countdowns[i] || null;
}

function nextIndex(countdowns, current) {
  if (!countdowns || countdowns.length === 0) return 0;
  return ((current || 0) + 1) % countdowns.length;
}
