extends Control
@onready var HTTP : HTTPRequest = $HTTPRequest
@onready var items : ItemList = $background/main_page/files_panel/ItemList
@onready var tree : Tree = $background/main_page/directories_panel/directory_tree
@onready var directory_texture = load("res://images/icons/folder.svg")
@onready var file_texture = load("res://images/icons/file.svg")
var fs_root = null
var directory_reference = {}
var file_info = {}
var selected_files = []
var active_file : int = 0
var connected_ip : String = ""
var connected_port : int = 0
var connecting = false
var selected_repo = null
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
	HTTP.request_completed.connect(init_cd)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "cd;~/")
	
func init_cd(result, response_code, headers, body):
	HTTP.request_completed.disconnect(init_cd)
	HTTP.request_completed.connect(obtain_ls_and_tree)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "ls")

func obtain_ls_and_tree(result, response_code, headers, body):
	receive_ls(result, response_code, headers, body)
	HTTP.request_completed.disconnect(obtain_ls_and_tree)
	HTTP.request_completed.connect(set_tree_response)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "tree")
	$background/main_page.visible = true

func set_tree_response(result, response_code, headers, body):
	fs_root = tree.create_item()
	var root = tree.create_item(fs_root)
	root.set_text(0, "~/")
	body = body.get_string_from_utf8()
	var selected = root
	var directories = {}
	directories["~/"] = root
	directory_reference[root] = "~/"
	for item in body.split(";"):
		var item_splits = item.split("|")
		if len(item_splits) < 2:
			continue
		var isdir = item_splits[1]
		var item_name = item_splits[0]
		item_name = item_name.substr(2)
		var item_dirsplits = item_name.split("/")
		var dirname = "~/"
		if len(item_dirsplits) > 1:
			dirname = "/".join(item_dirsplits.slice(0, len(item_dirsplits) - 1))
		var fname = item_dirsplits[len(item_dirsplits) - 1]
		selected = directories[dirname]
		var new_item = tree.create_item(selected)
		if isdir == "0":
			directories[item_name] = new_item
			directory_reference[new_item] = item_name
			new_item.set_icon(0, directory_texture)
		else:
			new_item.set_icon(0, file_texture)
		new_item.set_text(0, fname)
	HTTP.request_completed.disconnect(set_tree_response)
	HTTP.request_completed.connect(tree_repos_response)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "repos")

func update_repo_icon(result, response_code, headers, body):
	var image = Image.new()
	image.load_png_from_buffer(body)
	var icon_texture = ImageTexture.new()
	icon_texture.create_from_image(image)
	selected_repo.set_icon(0, icon_texture)
	
func tree_repos_response(result, response_code, headers, body):
	body = body.get_string_from_utf8()
	var repos_tree = tree.create_item(fs_root)
	repos_tree.set_text(0, "repositories")
	var splits = body.split(";")
	var categories = {}
	for repo in splits:
		var parts = repo.split("|")
		# name|category|url|raw
		var category = parts[1]
		if not category in categories.keys():
			var new_cat = tree.create_item(repos_tree)
			new_cat.set_text(0, category)
			categories[category] = new_cat
		selected_repo = tree.create_item(categories[category])
		selected_repo.set_text(0, parts[0])
		if parts[3] == "1":
			HTTP.request_completed.disconnect(tree_repos_response)
			var new_url = url + "/" + category + "/" + parts[0] + "/icon.png"
			HTTP.request_completed.connect(update_repo_icon)
			HTTP.request(new_url)
			
		

func receive_ls(result, response_code, headers, body):
	body = body.get_string_from_utf8()
	var splits = body.split(";")
	items.clear()
	items.add_item("..")
	selected_files = [".."]
	file_info = {}
	for file_dir in splits:
		var file_dir_parts = file_dir.split("|")
		var fname = file_dir_parts[0]
		selected_files.append(fname)
		var icon = file_texture
		if file_dir_parts[1] == "0":
			file_info[fname] = {"file_count": file_dir_parts[2], "is": "dir"}
			icon = directory_texture
		else:
			file_info[fname] = {"size": file_dir_parts[2], "is": "file"}
		items.add_item(fname, icon)
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
	if file_info[selected_files[active_file]]["is"] == "dir":
		var reader := ZIPReader.new()
		var err := reader.open(dl_path)
		var dl_dir_splits = dl_path.split("/")
		var dl_dir = "/".join(dl_dir_splits.slice(0, len(dl_dir_splits) - 1))
		var fdir = DirAccess.open(dl_dir)
		var fname = dl_dir_splits[len(dl_dir_splits) - 1]
		fdir.rename(fname, 
		"archive-" + fname)
		fdir.make_dir_absolute(dl_dir + "/" + fname)
		for file in reader.get_files():
			var current_file_direc = file.split("/")
			current_file_direc = "/".join(current_file_direc.slice(0, len(current_file_direc) - 1))
			fdir.make_dir_recursive_absolute(dl_path + current_file_direc)
			var raw_file = reader.read_file(file)
			var filea = FileAccess.open(dl_path + file, FileAccess.WRITE)
			filea.store_string(raw_file.get_string_from_utf8())
			filea.close()
		fdir.remove("archive-" + fname)
	else:
		print(file_info[selected_files[active_file]])

func _on_item_list_item_activated(index):
	var selected_file = selected_files[index]
	if not selected_file.contains(".") or selected_file == "..":
		HTTP.request_completed.connect(receive_cd)
		HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "cd;" + selected_file)

func _on_item_list_item_selected(index, pos, mb):
	var selected_file = selected_files[index]
	var fileinfo_box = $background/main_page/inspector_panel/fileinfo
	if selected_file == "..":
		fileinfo_box.visible = false
		return
	active_file = index
	fileinfo_box.visible = true
	var this_file = file_info[selected_file]
	fileinfo_box.get_child(0).text = selected_file
	var is_dir = this_file["is"] == "dir"
	if not is_dir:
		fileinfo_box.get_child(1).text = selected_file.split(".")[1] + " file"
		fileinfo_box.get_child(2).text = "file size: " + this_file["size"]
		fileinfo_box.get_child(6).visible = false
		fileinfo_box.get_child(4).visible = true
		fileinfo_box.get_child(8).visible = false
	else:
		fileinfo_box.get_child(1).text = "directory: " + selected_file
		fileinfo_box.get_child(2).text = this_file["file_count"] + " items"
		#  6 is the paste_into button, 4 is the open button.
		fileinfo_box.get_child(6).visible = true
		fileinfo_box.get_child(4).visible = false
		fileinfo_box.get_child(8).visible = true
		
func _on_download_selected_pressed():
	$download_popup.popup()

func _on_download_popup_confirmed(path):
	var popup = $download_popup
	dl_path = popup.current_path
	HTTP.request_completed.connect(receive_download)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "download;" + selected_files[active_file])

func _on_directory_tree_item_selected():
	var selected = tree.get_selected()
	if selected in directory_reference.keys():
		var selected_item_name = directory_reference[selected]
		HTTP.request_completed.connect(receive_cd)
		HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, 
		"cd;" + "~/" + selected_item_name)
		
func post_upload(result, response_code, headers, body):
	HTTP.request_completed.disconnect(post_upload)
	HTTP.request_completed.connect(receive_ls)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, "ls")

func do_upload(result, response_code, headers, body):
	HTTP.request_completed.disconnect(do_upload)
	print("hello?")
	body = body.get_string_from_utf8()
	HTTP.request_completed.connect(post_upload)
	var file = FileAccess.open(dl_path, FileAccess.READ)
	var file_contents = file.get_as_text()
	HTTP.request(url + body, ["Content-Type: text"], HTTPClient.METHOD_POST, 
	file_contents + "|!EOF")

func _on_upload_confirm(path):
	HTTP.request_completed.connect(do_upload)
	var popup = $download_popup
	dl_path = popup.current_path
	var fname_splits = dl_path.split("/")
	popup.confirmed.disconnect(_on_upload_confirm)
	popup.confirmed.connect(do_upload)
	HTTP.request(url, ["Content-Type: text"], HTTPClient.METHOD_POST, 
	"upload;" + fname_splits[len(fname_splits) - 1])

func _on_upload_into_pressed():
	var popup = $download_popup
	popup.file_selected.disconnect(_on_download_popup_confirmed)
	popup.file_selected.connect(_on_upload_confirm)
	popup.file_mode = 0
	popup.popup()
	
