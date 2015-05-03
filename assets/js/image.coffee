#= require common
#= require lib/spin.min.js
#= require modules/moduleloader
#= require modules/analytics
#= require modules/template
#= require modules/modalwindow

$window = $(window)
$imageContainer = null
$image = null
$modalWindow = null
fullScreen = false
URLObject = window.URL or window.webkitURL

setSize = () ->
	width = $(window).outerWidth()
	height = Math.min($(window).outerHeight(), ($image.outerHeight() + 65))

	$imageContainer.css
		width: width
		height: height

setPosition = () ->
	if $imageContainer.outerHeight() < $window.outerHeight()
		$imageContainer.css
			top: $window.outerHeight() / 2 - $imageContainer.outerHeight() / 2
	else
		$imageContainer.css
			top: ""

blobConstructorSupported = ->
	try
		new window.Blob
		return true
	catch e
		return false

arrayBufferResponseSupported = ->
	try
		(new XMLHttpRequest()).responseType = "arraybuffer"
		return true
	catch e
		return false

progressBarSupported = ->
	!!(
		("FormData" of window) and # XHR 2
		window.ArrayBuffer and
		URLObject and
		window.Blob and
		blobConstructorSupported() and
		arrayBufferResponseSupported()
	)

loadImage = ->
	spinner = new Spinner(
		color: "#eee"
		lines: 12
		length: 5
		width: 3
		radius: 6
		hwaccel: true
		className: "spin"
	).spin($(".spinner")[0]);

	$image.on "load", (e) ->
		spinner.stop()

	$image.attr "src", $image.data("src")

loadImageWithProgress = ->
	$progress = $ ".progress"
	$progressBar = $progress.find ".bar"
	$progress.addClass "appear"

	xhr = new XMLHttpRequest()
	xhr.responseType = "arraybuffer"
	imageSource = $image.data("src")

	xhr.addEventListener "progress", (e) ->
		$progressBar.css("width", (e.loaded / e.total) * 100 + "%")

	xhr.addEventListener "load", ->
		opts = {}
		type = imageSource.match(/.*\.(.*)$/)[1]
		opts["type"] = "image/#{type}" if type

		$image.attr "src", URLObject.createObjectURL(new Blob([this.response], opts))
		$progressBar.addClass "done"

	xhr.open "GET", imageSource
	xhr.send()

	$image.on "load", ->
		$progress.hide()

imageLoaded = ->
	setPosition()
	$image.addClass("appear")
	window.drawBackgroundOverlay()

confirmDelete = (e) ->
	image =  $(this).data("image")
	pasteboard.modalWindow.show "confirm",
		content: "Are you sure you want to delete this image?",
		showConfirm: true,
		confirmText: "Yes, delete",
		showCancel: true
		cancelText: "No, cancel"

	$modalWindow.on "confirm", ->
		$modalWindow.off "confirm cancel"
		$.post "images/#{image}/delete", ->
			window.location = "/"

	$modalWindow.on "cancel", ->
		$modalWindow.off "confirm cancel"
		pasteboard.modalWindow.hide()

toggleFullscreen = ->
	fullScreen = !fullScreen
	$("body").toggleClass("full-screen")
	$(window).scrollTop(0)

	if fullScreen
		setSize()
		$window.on "resize", setSize
	else
		$window.off "resize", setSize
		$imageContainer.css
			width: ""
			height: ""

	setPosition()


getViews = ->
	return unless window.location.pathname
	$.getJSON "analytics/views/#{location.pathname.replace "/", ""}", (response) ->
		$(".views").addClass("appear").find(".num").text(response.views or 1)

pasteboard = {}
window.moduleLoader.load("analytics", pasteboard)
window.moduleLoader.load("template", pasteboard)
window.moduleLoader.load("modalWindow", pasteboard)

$ () ->
	$imageContainer = $(".image-container")
	$image = $imageContainer.find(".image")

	if progressBarSupported()
		loadImageWithProgress()
	else
		loadImage()

	getViews()

	$image.on "load", imageLoaded
	$image.on "error", (e) -> $("body").addClass "broken"

	pasteboard.analytics.init()
	pasteboard.modalWindow.init()
	$modalWindow = $ pasteboard.modalWindow

	$window.on "resize", setPosition
	$image.on "click", toggleFullscreen
	$(".delete").click confirmDelete