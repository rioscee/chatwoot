<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import dealApi from '../../../../api/deals';
import { useAccount } from 'dashboard/composables/useAccount';
import axios from 'axios';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  stages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'created']);

const { t } = useI18n();
const { accountId } = useAccount();

const name = ref('');
const value = ref(0);
const currency = ref('USD');
const selectedStageId = ref(null);
const contactSearchQuery = ref('');
const contacts = ref([]);
const selectedContact = ref(null);
const isSearchingContacts = ref(false);
const showContactSuggestions = ref(false);
const isSaving = ref(false);
const error = ref(null);

watch(
  () => props.stages,
  newStages => {
    if (newStages && newStages.length > 0 && !selectedStageId.value) {
      selectedStageId.value = newStages[0].id;
    }
  },
  { immediate: true }
);

watch(contactSearchQuery, async query => {
  if (query.length < 2) {
    contacts.value = [];
    return;
  }
  isSearchingContacts.value = true;
  try {
    const response = await axios.get(
      `/api/v1/accounts/${accountId.value}/contacts/search?q=${encodeURIComponent(query)}`
    );
    contacts.value = response.data.payload || [];
  } catch (err) {
    console.error('Error searching contacts:', err);
  } finally {
    isSearchingContacts.value = false;
  }
});

const selectContact = contact => {
  selectedContact.value = contact;
  contactSearchQuery.value = contact.name;
  showContactSuggestions.value = false;
};

const clearContact = () => {
  selectedContact.value = null;
  contactSearchQuery.value = '';
};

const closeModal = () => {
  name.value = '';
  value.value = 0;
  currency.value = 'USD';
  selectedContact.value = null;
  contactSearchQuery.value = '';
  error.value = null;
  emit('close');
};

const submit = async () => {
  if (!name.value) {
    error.value = 'El nombre del trato es obligatorio';
    return;
  }
  if (value.value < 0) {
    error.value = 'El valor no puede ser negativo';
    return;
  }
  if (!selectedStageId.value) {
    error.value = 'Debes seleccionar una etapa';
    return;
  }

  isSaving.value = true;
  error.value = null;

  try {
    const payload = {
      name: name.value,
      value: value.value,
      currency: currency.value,
      pipeline_stage_id: selectedStageId.value,
      contact_id: selectedContact.value ? selectedContact.value.id : null,
    };
    const response = await dealApi.create(payload);
    emit('created', response.data);
    closeModal();
  } catch (err) {
    error.value = 'Ocurrió un error al guardar el trato. Inténtalo de nuevo.';
    console.error('Error creating deal:', err);
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <woot-modal :show="show" :on-close="closeModal">
    <div class="modal-container">
      <woot-modal-header header-title="Crear Nuevo Trato" />
      
      <form @submit.prevent="submit" class="deal-form">
        <div v-if="error" class="error-banner">
          {{ error }}
        </div>

        <div class="form-group">
          <label class="form-label">Nombre del Trato</label>
          <input
            v-model="name"
            type="text"
            placeholder="Ej. Venta de Licencias SaaS"
            class="form-input"
            required
          />
        </div>

        <div class="form-row">
          <div class="form-group val-group">
            <label class="form-label">Valor</label>
            <input
              v-model.number="value"
              type="number"
              min="0"
              step="0.01"
              class="form-input"
              required
            />
          </div>

          <div class="form-group cur-group">
            <label class="form-label">Moneda</label>
            <select v-model="currency" class="form-select">
              <option value="USD">USD ($)</option>
              <option value="EUR">EUR (€)</option>
              <option value="COP">COP ($)</option>
              <option value="MXN">MXN ($)</option>
              <option value="ARS">ARS ($)</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">Etapa del Embudo</label>
          <select v-model="selectedStageId" class="form-select" required>
            <option v-for="stage in stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </div>

        <div class="form-group relative">
          <label class="form-label">Asociar Contacto (Cliente)</label>
          <div class="input-wrapper">
            <input
              v-model="contactSearchQuery"
              type="text"
              placeholder="Buscar por nombre, email o teléfono..."
              class="form-input"
              @focus="showContactSuggestions = true"
              :disabled="selectedContact !== null"
            />
            <button
              v-if="selectedContact"
              type="button"
              class="clear-btn"
              @click="clearContact"
            >
              ✕
            </button>
          </div>

          <div
            v-if="showContactSuggestions && contactSearchQuery.length >= 2 && contacts.length > 0"
            class="suggestions-dropdown"
          >
            <div
              v-for="contact in contacts"
              :key="contact.id"
              class="suggestion-item"
              @click="selectContact(contact)"
            >
              <div class="suggestion-name">{{ contact.name }}</div>
              <div class="suggestion-meta">
                {{ contact.email || contact.phone_number || 'Sin datos de contacto' }}
              </div>
            </div>
          </div>
          <div
            v-if="showContactSuggestions && contactSearchQuery.length >= 2 && contacts.length === 0 && !isSearchingContacts"
            class="suggestions-dropdown empty"
          >
            No se encontraron contactos.
          </div>
        </div>

        <div class="form-actions">
          <button
            type="button"
            class="cancel-button"
            @click="closeModal"
          >
            Cancelar
          </button>
          <NextButton
            type="submit"
            :loading="isSaving"
            label="Guardar Trato"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>

<style scoped>
/* CSS Puro para cumplir la regla global */
.modal-container {
  display: flex;
  flex-direction: column;
  height: auto;
  max-height: 85vh;
  padding: 1.5rem;
  box-sizing: border-box;
}

.deal-form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  width: 100%;
  margin-top: 1rem;
}

.error-banner {
  background-color: var(--r-500, #ff4a4a);
  color: #fff;
  padding: 0.75rem 1rem;
  border-radius: 6px;
  font-size: clamp(14px, 1.2vw, 16px);
  font-weight: 500;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-row {
  display: flex;
  gap: 1rem;
  width: 100%;
}

.val-group {
  flex: 2;
}

.cur-group {
  flex: 1;
}

.form-label {
  font-size: clamp(13px, 1.1vw, 15px);
  font-weight: 600;
  color: var(--s-700, #333333);
}

.form-input,
.form-select {
  padding: 0.75rem 1rem;
  border: 1px solid var(--s-200, #e2e8f0);
  border-radius: 6px;
  background-color: var(--white, #ffffff);
  color: var(--s-900, #0f172a);
  font-size: clamp(14px, 1.2vw, 16px);
  box-sizing: border-box;
  outline: none;
  transition: border-color 0.2s ease;
}

.form-input:focus,
.form-select:focus {
  border-color: var(--b-500, #2563eb);
}

.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  width: 100%;
}

.input-wrapper .form-input {
  width: 100%;
  padding-right: 2.5rem;
}

.clear-btn {
  position: absolute;
  right: 0.75rem;
  background: none;
  border: none;
  color: var(--s-400, #94a3b8);
  font-size: 14px;
  cursor: pointer;
  padding: 4px;
  border-radius: 50%;
  transition: background-color 0.2s ease, color 0.2s ease;
}

.clear-btn:hover {
  background-color: var(--s-100, #f1f5f9);
  color: var(--s-700, #334155);
}

.relative {
  position: relative;
}

.suggestions-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background-color: var(--white, #ffffff);
  border: 1px solid var(--s-200, #e2e8f0);
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  z-index: 10;
  max-height: 200px;
  overflow-y: auto;
  margin-top: 0.25rem;
}

.suggestions-dropdown.empty {
  padding: 1rem;
  color: var(--s-500, #64748b);
  font-size: 14px;
  text-align: center;
}

.suggestion-item {
  padding: 0.75rem 1rem;
  cursor: pointer;
  transition: background-color 0.2s ease;
  border-bottom: 1px solid var(--s-100, #f1f5f9);
}

.suggestion-item:last-child {
  border-bottom: none;
}

.suggestion-item:hover {
  background-color: var(--s-50, #f8fafc);
}

.suggestion-name {
  font-weight: 600;
  font-size: clamp(14px, 1.2vw, 16px);
  color: var(--s-900, #0f172a);
}

.suggestion-meta {
  font-size: clamp(12px, 1vw, 13px);
  color: var(--s-500, #64748b);
  margin-top: 0.15rem;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  margin-top: 1rem;
}

.cancel-button {
  padding: 0.75rem 1.5rem;
  background: none;
  border: 1px solid var(--s-200, #e2e8f0);
  border-radius: 6px;
  color: var(--s-600, #475569);
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.cancel-button:hover {
  background-color: var(--s-50, #f8fafc);
}

.form-input,
.form-select,
.cancel-button,
.clear-btn {
  font-family: inherit;
}
</style>
