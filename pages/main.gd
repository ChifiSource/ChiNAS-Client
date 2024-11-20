extends Control
@onready var HTTP : HTTPRequest = $HTTPRequest
@onready var items : ItemList = $background/main_page/files_panel/ItemList
var selected_files = []
var active_file : int = 0
var connected_ip : String = ""
var connected_port : int = 0
var connecting = false
var url : String
var dl_path : String
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_connect_button_pressed():
	connecting = true
	connected_ip = $background/connect_page/connect_container/HBoxContainer/ipbox.text
	connected_port = $background/connect_page/connect_container/HBoxContainer/portbox.value
	HTTP.request_completed.connect(on_init_response)
	HTTP.request("http://" + connected_ip + ":" + str(connected_port))
 	
# the server is up, we provide the key
func on_init_response(result, response_code, headers, body):
	HTTP.request_completed.disconnect(on_init_response)
	HTTP.request_completed.connect(on_secret_response)
	var secret = $background/connect_page/connect_container/secretbox.text
	HTTP.request("http://" + connected_ip + ":" + str(connected_port) + "/?secret=" + secret)

# secret verified, we ask for username
func on_secret_response(result, response_code, headers, body):
	body = body.get_string_from_utf8()
	if body != "denied":
		$background/connect_page.visible = false
		$background/username_box.visible = true
	HTTP.request_completed.disconnect(on_secret_response)

func _on_login_button_pressed():
	var name = $background/username_box/VBoxContainer/usernamebox.text
	HTTP.request_completed.connect(on_nameset)
	HTTP.request("http://" + connected_ip + ":" + str(connected_port) + "/?name=" + name)
	url = "http://" + connected_ip + ":" + str(connected_port)
	
func on_nameset(result, response_code, headers, body):
	$background/username_box.visible = false
	HTTP.request_completed.disconnect(on_nameset)
	HTTP.request_completed.connect(receive_ls)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "ls")
	$background/main_page.visible = true

func receive_ls(result, response_code, headers, body):
	body = body.get_string_from_utf8()
	var splits = body.split(";")
	items.clear()
	items.add_item("..")
	selected_files = [".."]
	for file_dir in splits:
		selected_files.append(file_dir)
		items.add_item(file_dir)
	HTTP.request_completed.disconnect(receive_ls)

func receive_cd(result, response_code, headers, body):
	HTTP.request_completed.disconnect(receive_cd)
	HTTP.request_completed.connect(receive_ls)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "ls")

func receive_download(result, response_code, headers, body):
	HTTP.request_completed.disconnect(receive_download)
	# download URL
	body = body.get_string_from_utf8()
	# we set download file, and make GET request to download link.
	HTTP.download_file = dl_path
	HTTP.request_completed.connect(finalize_download)
	HTTP.request(url + body)
	
func finalize_download(result, response_code, headers, body):
	pass # for now this will do nothing, in the future it will present a message.

func _on_item_list_item_activated(index):
	var selected_file = selected_files[index]
	if not selected_file.contains(".") or selected_file == "..":
		HTTP.request_completed.connect(receive_cd)
		HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "cd;" + selected_file)


func _on_item_list_item_selected(index, pos, mb):
	var selected_file = selected_files[index]
	if not selected_file.contains("."):
		return
	active_file = index
	var file_info = $background/main_page/inspector_panel/fileinfo
	file_info.visible = true
	file_info.get_child(0).text = selected_file
	file_info.get_child(1).text = selected_file.split(".")[1] + " file"

func _on_download_selected_pressed():
	$download_popup.popup()

func _on_download_popup_confirmed():
	var popup = $download_popup
	dl_path = popup.current_path
	HTTP.request_completed.connect(receive_download)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "download;" + selected_files[active_file])
