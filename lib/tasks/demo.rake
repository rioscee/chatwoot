namespace :demo do
  desc 'Poblar el CRM con datos de prueba realistas para demostraciones (Contactos, Conversaciones y Tratos Kanban)'
  task poblar: :environment do
    puts '🚀 Iniciando la carga de datos de prueba para la Demo...'

    account = Account.first
    unless account
      puts '❌ No se encontró ninguna cuenta. Por favor abre la app primero para inicializar la cuenta.'
      next
    end

    user = account.users.first

    # 1. Asegurar que existe el Embudo de Ventas y sus etapas
    pipeline = account.pipelines.first
    unless pipeline
      pipeline = account.pipelines.create!(name: 'Embudo de Ventas Principal')
      default_stages = [
        { name: 'Prospecto', position: 1 },
        { name: 'Contacto Realizado', position: 2 },
        { name: 'Demostración Programada', position: 3 },
        { name: 'Propuesta Enviada', position: 4 },
        { name: 'Negociación Iniciada', position: 5 }
      ]
      default_stages.each do |stg|
        pipeline.pipeline_stages.create!(stg.merge(account_id: account.id))
      end
    end

    stages = pipeline.pipeline_stages.order(:position).to_a
    if stages.empty?
      puts '❌ El embudo no tiene etapas creadas.'
      next
    end

    # 2. Crear Contactos de Prueba
    sample_contacts_data = [
      { name: 'María García', email: 'maria.garcia@ejemplo.com', phone_number: '+51987654321' },
      { name: 'Carlos Mendoza', email: 'carlos.mendoza@ejemplo.com', phone_number: '+51912345678' },
      { name: 'Ana Lucía Rodríguez', email: 'ana.rodriguez@ejemplo.com', phone_number: '+51923456789' },
      { name: 'Diego Morales', email: 'diego.morales@ejemplo.com', phone_number: '+51934567890' },
      { name: 'Valentina Torres', email: 'valentina.torres@ejemplo.com', phone_number: '+51945678901' },
      { name: 'Fernando Gómez', email: 'fernando.gomez@ejemplo.com', phone_number: '+51956789012' },
      { name: 'Sofía Vargas', email: 'sofia.vargas@ejemplo.com', phone_number: '+51967890123' },
      { name: 'Jorge Silva', email: 'jorge.silva@ejemplo.com', phone_number: '+51978901234' },
      { name: 'Camila Ríos', email: 'camila.rios@ejemplo.com', phone_number: '+51989012345' },
      { name: 'Mateo Fernández', email: 'mateo.fernandez@ejemplo.com', phone_number: '+51990123456' }
    ]

    contacts = sample_contacts_data.map do |data|
      account.contacts.find_or_create_by!(email: data[:email]) do |c|
        c.name = data[:name]
        c.phone_number = data[:phone_number]
      end
    end
    puts "✅ #{contacts.count} contactos de prueba listos."

    # 3. Crear Conversaciones de Prueba
    inbox = account.inboxes.first
    if inbox
      sample_messages = [
        '¡Hola! Quisiera información sobre los planes de suscripción para mi negocio.',
        'Buenas tardes, ¿tienen disponibilidad para agendar una demostración mañana?',
        'Hola, me gustaría saber si el CRM se puede conectar con mi cuenta de Instagram.',
        '¿Cuáles son los métodos de pago disponibles?',
        'Hola, vi su publicación y me interesa instalar el sistema en mi tienda.'
      ]

      contacts.first(5).each_with_index do |contact, idx|
        contact_inbox = ::ContactInbox.find_or_create_by!(contact_id: contact.id, inbox_id: inbox.id) do |ci|
          ci.source_id = SecureRandom.uuid
        end

        conversation = account.conversations.find_or_create_by!(contact_id: contact.id, inbox_id: inbox.id) do |conv|
          conv.contact_inbox_id = contact_inbox.id
          conv.status = 'open'
          conv.assignee_id = user&.id
        end

        if conversation.messages.empty?
          conversation.messages.create!(
            account_id: account.id,
            inbox_id: inbox.id,
            content: sample_messages[idx % sample_messages.length],
            message_type: :incoming,
            sender: contact
          )
        end
      end
      puts '✅ Conversaciones y mensajes de prueba generados.'
    end

    # 4. Crear Tratos (Deals) en el Embudo Kanban
    deals_data = [
      { name: 'Plan Anual Pizzería Bella', value: 1200, stage: stages[0], contact: contacts[0] },
      { name: 'Servicio CRM Barbería Club', value: 450, stage: stages[0], contact: contacts[1] },
      { name: 'Implementación Tienda Calzado', value: 850, stage: stages[1], contact: contacts[2] },
      { name: 'Consultoría Multicanal', value: 300, stage: stages[1], contact: contacts[3] },
      { name: 'Demostración Plataforma VIP', value: 1500, stage: stages[2], contact: contacts[4] },
      { name: 'Licencia 5 Usuarios Vendedores', value: 950, stage: stages[3], contact: contacts[5] },
      { name: 'Paquete Empresarial Completo', value: 2400, stage: stages[3], contact: contacts[6] },
      { name: 'Cierre de Contrato Anual', value: 3200, stage: stages[4], contact: contacts[7] },
      { name: 'Renovación de Licencia', value: 600, stage: stages[4], contact: contacts[8] }
    ]

    deals_data.each_with_index do |d, idx|
      Deal.find_or_create_by!(name: d[:name], account_id: account.id) do |deal|
        deal.value = d[:value]
        deal.pipeline_stage_id = d[:stage].id
        deal.contact_id = d[:contact].id
        deal.position = idx + 1
        deal.status = 'open'
      end
    end
    puts "✅ #{deals_data.count} tratos creados y distribuidos en el tablero Kanban."

    puts '🎉 ¡El CRM ahora está completamente poblado con datos de demostración!'
  end

  desc 'Limpiar todos los datos de prueba dejando la instalación 100% como nueva para un cliente'
  task limpiar: :environment do
    puts '🧹 Limpiando datos de prueba del CRM...'

    account = Account.first
    unless account
      puts '❌ No se encontró ninguna cuenta.'
      next
    end

    # 1. Borrar todos los tratos (Deals)
    deals_count = account.deals.count
    account.deals.destroy_all
    puts "🗑️ Se eliminaron #{deals_count} tratos del Kanban."

    # 2. Borrar mensajes y conversaciones
    conv_count = account.conversations.count
    account.conversations.destroy_all
    puts "🗑️ Se eliminaron #{conv_count} conversaciones de prueba."

    # 3. Borrar contactos de prueba
    contacts_count = account.contacts.count
    account.contacts.destroy_all
    puts "🗑️ Se eliminaron #{contacts_count} contactos."

    puts '✨ ¡El CRM ha sido limpiado por completo! Está listo como nuevo para entregárselo a tu cliente.'
  end
end
