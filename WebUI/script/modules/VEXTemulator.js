/*

	This file emulates vext responses and returns dummy data.
	This allows us to develop the UI completely in the browser.

 */
class VEXTemulator {
	constructor() {
		this.commands = {};
		this.commands['SpawnBlueprintCommand'] = this.SpawnBlueprint;
		this.commands['DestroyBlueprintCommand'] = this.DestroyBlueprint;
	}


	SpawnBlueprint(command) {
		// Spawn blueprint at coordinate
		// Blueprint spawns, we get a list of entities
		// We send the whole thing to web again.

		let response = {
			"guid": command.guid,
			"sender": command.sender,
			"type": "SpawnedBlueprint",
			"name": command.parameters.name,
			"transform": command.parameters.transform,
			"children": {
				1: {
					"type": "StaticModelEntity",
					"guid": GenerateGuid(),
					"entityId": GenerateGuid(),
					"localTransform": new LinearTransform(),
				},
				2: {
					"type": "EffectEntity",
					"guid": GenerateGuid(),
					"entityId": GenerateGuid(),
					"localTransform": new LinearTransform(),
				},
				3: {
					"type": "EffectEntity",
					"guid": GenerateGuid(),
					"entityId": GenerateGuid(),
					"localTransform": new LinearTransform(),
				}
			}
		};
		editor.vext.HandleResponse(response);
	}

	DestroyBlueprint(command) {
		// Delete all children of blueprint
		let response = {
			"type": "DestroyedBlueprint",
			"guid": command.guid
		};
		editor.vext.HandleResponse(response);
	}



}