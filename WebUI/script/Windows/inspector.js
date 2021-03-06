class Inspector {
	constructor() {
		this.dom = null;
		this.transform = null;
		this.name = null;
		this.Initialize();

	}

	//TODO: OnUpdate events, transform shit


	Initialize () {
		let content = $(document.createElement("div"));
		content.attr("id", "objectInspector");

		let nameControl = $(document.createElement("div"));
		content.append(nameControl);
		nameControl.addClass("name");

		let nameLabel = $(document.createElement("label"));
		nameControl.append(nameLabel);
		nameLabel.attr("for", "objectName");
		nameLabel.text("Name");

		let nameInput = $(document.createElement("input"));
		nameControl.append(nameInput);
		nameInput.attr({
			"id": "objectName",
			"type": "text",
			"value": "name"
		});
		this.name = nameInput;

		let transformControl = $(document.createElement("div"));
		transformControl.addClass("transform");
		content.append(transformControl);
		this.transform = {};

		let deleteButton = $(document.createElement("button"));
		deleteButton.addClass("deleteButton");
		deleteButton.text("Delete");
		deleteButton.click(function(){
			editor.ui.dialogs["deleteEntity"].dialog("open");
		});
		content.append(deleteButton);


		let controls = ["position", "rotation", "scale"];
		let xyz = ["x","y","z"];
		let transform = this.transform;
		let inspector = this;
		$.each(controls, function (index, con) {
			transformControl.append("<h2>" + con + "</h2>");
			let controller = $(document.createElement("div"));
			transformControl.append(controller);
			controller.addClass(con);
			transform[con] = {};

			$.each(xyz, function(index2, val) {
				let label = $(document.createElement("label"));
				controller.append(label);
				label.attr("for", con +val);
				label.text(val + ":");
				let inp = $(document.createElement("input"));
				inp.attr({
					"name": con+val,
					"id": con+val,
					"type": "number",
					"value": "0"
				});
				inp.spinner({
				  step: 0.01,
				  numberFormat: "n"
				});
				controller.append(inp);
				transform[con][val] = inp;
				inp.on('input', function(e) {
					inspector.SetTransform(con, val, $(this).val());
				});

				label.on('mousedown', handleMouse);

				//TODO: Link the values directly somehow?
			})
		});
		this.dom = content;
	}

	SetTransform(type, key, value) {
		// TODO: The displayed rotation is technically correct, it just doesn't display the way I want it to. Make sure the rotation displays in an unoptimal way.
		if(isNaN(value) || value == "") {
			console.log("shitballs")
			this.transform[type][key].addClass("invalid")
			return
		}
		if(this.transform[type][key].hasClass("invalid")) {
			this.transform[type][key].removeClass("invalid")
		}
		if(type == "rotation") {
				let eulerRot = new THREE.Euler( this.transform.rotation.x.val() * THREE.Math.DEG2RAD, this.transform.rotation.y.val() * THREE.Math.DEG2RAD, this.transform.rotation.z.val() * THREE.Math.DEG2RAD);
				console.log(eulerRot);

			editor.selectedEntity.webObject.rotation.copy(eulerRot);
		} else {
		   editor.selectedEntity.webObject[type][key] = Number(value);
		}
		editor.webGL.Render();
		editor.selectedEntity.OnMove(true);
	}

	UpdateInspector(gameObject) {
		if(gameObject == null) {
			console.log("Tried to update the inspector with an invalid gameobject?");
			return
		}
		this.name[0].value = gameObject.name;

		let controls = ["position", "rotation", "scale"];
		let xyz = ["x","y","z"];
		let transform = this.transform;
		$.each(controls, function (index, con) {
			let control = gameObject.webObject[con];
			$.each(xyz, function(index2, val) {


				if(isNaN(control[val])) {
					transform[con][val].addClass("invalid")
					return
				}
				if(transform[con][val].hasClass("invalid")) {
					transform[con][val].removeClass("invalid")
				}


				//If we're modifying Rotation. Using the controls key for redundancy
				if(con == controls[1]) {
					transform[con][val][0].value = control[val] * THREE.Math.RAD2DEG
				} else {
					transform[con][val][0].value =control[val].toFixed(3)
				}
			});
		});
	}

	HideContent() {
		this.dom.hide()
	}
	ShowContent() {
		this.dom.show()
	}
}

